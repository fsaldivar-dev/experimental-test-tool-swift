//
//  XcodeIntegratorTests.swift
//  SpockGenTests
//
//  spock-gen mantiene el .xcodeproj sincronizado con Generated: grupos que reflejan las carpetas,
//  una referencia por archivo y una fase de script con outputs que regenera solo cuando falta.
//

import Testing
import Foundation
@testable import SpockGenCore

@Suite("SpockGenCore - Xcode: sincronización del pbxproj")
struct XcodeIntegratorTests {

    /// Copia del proyecto Example en una carpeta temporal, con su propia carpeta Generated.
    struct ProjectFixture {
        let root: URL
        let pbxproj: URL
        let generated: URL

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("spock-xcode-\(UUID().uuidString)")
            let project = root.appendingPathComponent("Example.xcodeproj")
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
            pbxproj = project.appendingPathComponent("project.pbxproj")
            try FileManager.default.copyItem(atPath: "Example/Example.xcodeproj/project.pbxproj", toPath: pbxproj.path)
            generated = root.appendingPathComponent("ExampleTests/Generated")
        }

        func tearDown() { try? FileManager.default.removeItem(at: root) }

        func writeGenerated(_ relativePath: String) throws {
            let url = generated.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "// generado".write(to: url, atomically: true, encoding: .utf8)
        }

        var content: String { (try? String(contentsOf: pbxproj, encoding: .utf8)) ?? "" }

        var request: XcodeProjectIntegrator.SyncRequest {
            .init(projectPbxprojPath: pbxproj.path, targetName: "ExampleTests", generatedDirectory: generated.path, generateCommand: "/usr/bin/swift run spock-gen --no-xcode")
        }
    }

    @Test("sync crea grupos espejo, referencias, entradas en Sources y la fase con outputs")
    func testSyncBuildsTheTree() throws {
        let fixture = try ProjectFixture()
        defer { fixture.tearDown() }
        try fixture.writeGenerated("Example/Domain/Stubs/User+Stub.swift")
        try fixture.writeGenerated("Example/Domain/Mocks/UserRepositoryProtocol+Mock.swift")

        let status = try XcodeProjectIntegrator.sync(fixture.request)
        #expect(status == .synchronized(filesCount: 2))

        let content = fixture.content
        // Referencias y build files
        #expect(content.contains("/* User+Stub.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"User+Stub.swift\"; sourceTree = \"<group>\"; };"))
        #expect(content.contains("/* UserRepositoryProtocol+Mock.swift in Sources */ = {isa = PBXBuildFile;"))
        // Grupos espejo: Generated > Example > Domain > Stubs / Mocks
        for path in ["Generated", "Example", "Domain", "Stubs", "Mocks"] {
            #expect(content.contains("\t\t\tpath = \(path);\n\t\t\tsourceTree = \"<group>\";"), "falta el grupo \(path)")
        }
        // El grupo Generated cuelga del grupo ExampleTests (DEBD4B00…), no del grupo Domain (4B60AE8D…)
        // La búsqueda de grupos se hace siempre sobre el proyecto sin objetos de spock-gen
        let cleaned = XcodeProjectIntegrator.removeManagedObjects(from: content)
        #expect(XcodeProjectIntegrator.groupId(withPath: "ExampleTests", in: cleaned) == "DEBD4B00168E447ABAFCB246")
        #expect(XcodeProjectIntegrator.groupId(withPath: "Domain", in: cleaned) == "4B60AE8D52F541B088AC0524")
        let generatedGroup = XcodeProjectIntegrator.objectId("group:")
        let exampleTestsBlock = try #require(content.range(of: "\t\tDEBD4B00168E447ABAFCB246 /* ExampleTests */ = {").map { content[$0.lowerBound...] })
        let exampleTestsChildren = exampleTestsBlock[..<(exampleTestsBlock.range(of: "\n\t\t};")!.lowerBound)]
        #expect(exampleTestsChildren.contains("\t\t\t\t\(generatedGroup) /* Generated */,"))
        let domainBlock = try #require(content.range(of: "\t\t4B60AE8D52F541B088AC0524 /* Domain */ = {").map { content[$0.lowerBound...] })
        let domainChildren = domainBlock[..<(domainBlock.range(of: "\n\t\t};")!.lowerBound)]
        #expect(!domainChildren.contains("/* Generated */"))
        // Fase de script: primera del target, con los dos outputs y sin inputs
        #expect(content.contains("\t\t\tbuildPhases = (\n\t\t\t\t\(XcodeProjectIntegrator.objectId("script:ExampleTests/Generated")) /* Spock: regenerar Generated si falta */,\n\t\t\t\tC57424A1588A47138ED504B3 /* Sources */,"))
        #expect(content.contains("\"$(SRCROOT)/ExampleTests/Generated/Example/Domain/Stubs/User+Stub.swift\","))
        #expect(content.contains("\"$(SRCROOT)/ExampleTests/Generated/Example/Domain/Mocks/UserRepositoryProtocol+Mock.swift\","))
        #expect(content.contains("alwaysOutOfDate = 1;"))
        // La fase corre spock-gen en cada build con entorno limpio; la caché lo hace barato
        #expect(content.contains("/usr/bin/env -i HOME=\\\"$HOME\\\""))
        #expect(content.contains("/usr/bin/swift run spock-gen --no-xcode"))
        // Entradas en la fase Sources del target de tests
        #expect(content.contains("/* User+Stub.swift in Sources */,\n"))
    }

    @Test("sync es idempotente y refleja archivos añadidos y eliminados")
    func testSyncIsIdempotentAndTracksChanges() throws {
        let fixture = try ProjectFixture()
        defer { fixture.tearDown() }
        try fixture.writeGenerated("Example/Domain/Stubs/User+Stub.swift")

        #expect(try XcodeProjectIntegrator.sync(fixture.request) == .synchronized(filesCount: 1))
        #expect(try XcodeProjectIntegrator.sync(fixture.request) == .upToDate(filesCount: 1))
        let first = fixture.content

        try fixture.writeGenerated("Example/Domain/Stubs/Pet+Stub.swift")
        #expect(try XcodeProjectIntegrator.sync(fixture.request) == .synchronized(filesCount: 2))
        #expect(fixture.content.contains("/* Pet+Stub.swift */ = {isa = PBXFileReference"))

        try FileManager.default.removeItem(at: fixture.generated.appendingPathComponent("Example/Domain/Stubs/Pet+Stub.swift"))
        #expect(try XcodeProjectIntegrator.sync(fixture.request) == .synchronized(filesCount: 1))
        #expect(fixture.content == first)
    }

    @Test("sync retira un grupo sincronizado Generated de una configuración anterior")
    func testSyncRemovesSynchronizedGroup() throws {
        let fixture = try ProjectFixture()
        defer { fixture.tearDown() }
        try fixture.writeGenerated("Example/Domain/Stubs/User+Stub.swift")

        // Simular lo que deja Xcode 16 al usar una carpeta sincronizada
        var content = XcodeProjectIntegrator.removeManagedObjects(from: fixture.content)
        let syncId = XcodeProjectIntegrator.objectPrefix + "0000000000000401"
        content = content.replacingOccurrences(
            of: "/* Begin PBXFrameworksBuildPhase section */",
            with: "/* Begin PBXFileSystemSynchronizedRootGroup section */\n\t\t\(syncId) /* Generated */ = {isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {}; explicitFolders = (); path = Generated; sourceTree = \"<group>\"; };\n/* End PBXFileSystemSynchronizedRootGroup section */\n\n/* Begin PBXFrameworksBuildPhase section */"
        )
        content = content.replacingOccurrences(
            of: "\t\t\tname = ExampleTests;\n",
            with: "\t\t\tfileSystemSynchronizedGroups = (\n\t\t\t\t\(syncId) /* Generated */,\n\t\t\t);\n\t\t\tname = ExampleTests;\n"
        )
        try content.write(to: fixture.pbxproj, atomically: true, encoding: .utf8)
        #expect(fixture.content.contains("PBXFileSystemSynchronizedRootGroup"))

        #expect(try XcodeProjectIntegrator.sync(fixture.request) == .synchronized(filesCount: 1))
        let synced = fixture.content
        #expect(!synced.contains("PBXFileSystemSynchronizedRootGroup"))
        #expect(!synced.contains("fileSystemSynchronizedGroups"))
        #expect(synced.contains("/* User+Stub.swift */ = {isa = PBXFileReference"))
    }

    @Test("sync avisa cuando el target no existe y no toca el proyecto")
    func testSyncUnknownTarget() throws {
        let fixture = try ProjectFixture()
        defer { fixture.tearDown() }
        try fixture.writeGenerated("Example/Domain/Stubs/User+Stub.swift")
        let before = fixture.content

        var request = fixture.request
        request.targetName = "Ghost"
        #expect(try XcodeProjectIntegrator.sync(request) == .targetNotFound("Ghost"))
        #expect(fixture.content == before)
    }
}
