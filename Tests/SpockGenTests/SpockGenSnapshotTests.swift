//
//  SpockGenSnapshotTests.swift
//  SpockGenTests
//
//  Los stubs se versionan como snapshots: el motor los escribe en
//  Generated/<Módulo>/<ruta>/Stubs/<Tipo>+Stub.swift, `check` detecta desfases y `clean` los borra.
//

import Testing
import Foundation
@testable import SpockGenCore

// MARK: - Fixture

/// Proyecto temporal con un módulo `App` (Data/Entities) y un módulo de tests `AppTests`.
struct SnapshotFixture {
    let root: URL
    let sources: URL
    let entities: URL
    let tests: URL
    let generated: URL
    let cache: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("spock-snapshot-\(UUID().uuidString)")
        sources = root.appendingPathComponent("Sources/App")
        entities = sources.appendingPathComponent("Data/Entities")
        tests = root.appendingPathComponent("Tests/AppTests")
        generated = tests.appendingPathComponent("Generated")
        cache = root.appendingPathComponent(".spock-cache.json")
        try FileManager.default.createDirectory(at: entities, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tests, withIntermediateDirectories: true)
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func write(_ content: String, to file: URL) throws {
        try content.write(to: file, atomically: true, encoding: .utf8)
    }

    func writeDomain(userHasEmail: Bool = false) throws {
        let email = userHasEmail ? "\n    public var email: String" : ""
        try write("public struct User {\n    public var name: String\(email)\n    public var pet: Pet\n}", to: entities.appendingPathComponent("User.swift"))
        try write("public struct Pet {\n    public var name: String\n}", to: entities.appendingPathComponent("Pet.swift"))
    }

    func writeTest(_ content: String, named name: String = "UserTests.swift") throws {
        try write(content, to: tests.appendingPathComponent(name))
    }

    func configuration(withCache: Bool = false) -> SpockGenEngine.Configuration {
        SpockGenEngine.Configuration(
            sourceRoots: [SourceRoot(module: "App", path: sources.path)],
            testRoots: [SourceRoot(module: "AppTests", path: tests.path)],
            outputDirectory: generated.path,
            cachePath: withCache ? cache.path : nil,
            verbose: false
        )
    }

    func engine(withCache: Bool = false) -> SpockGenEngine {
        SpockGenEngine(config: configuration(withCache: withCache))
    }

    func generatedContent(_ relativePath: String) throws -> String {
        try String(contentsOf: generated.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func generatedExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: generated.appendingPathComponent(relativePath).path)
    }

    static let userStub = "App/Data/Entities/Stubs/User+Stub.swift"
    static let petStub = "App/Data/Entities/Stubs/Pet+Stub.swift"
}

// MARK: - Layout

@Suite("SpockGenCore - Layout: la salida refleja la estructura del módulo")
struct OutputLayoutTests {

    @Test("SourceRoot acepta Módulo=ruta y, sin módulo, infiere el nombre del último componente")
    func testSourceRootParsing() {
        let explicit = SourceRoot.parse("App=Sources/App/")
        #expect(explicit.module == "App")
        #expect(explicit.path == "Sources/App")

        let inferred = SourceRoot.parse("./Example/Example/Domain")
        #expect(inferred.module == "Domain")
        #expect(inferred.path == "Example/Example/Domain")
        #expect(inferred.spec == "Domain=Example/Example/Domain")
    }

    @Test("SourceRoot calcula el directorio relativo de un archivo y rechaza los ajenos")
    func testSourceRootRelativeDirectory() {
        let root = SourceRoot(module: "App", path: "Sources/App")
        #expect(root.relativeDirectory(of: "Sources/App/Data/Entities/User.swift") == "Data/Entities")
        #expect(root.relativeDirectory(of: "Sources/App/User.swift") == "")
        #expect(root.relativeDirectory(of: "Sources/Other/User.swift") == nil)
    }

    @Test("OutputLayout coloca cada stub en <Módulo>/<ruta relativa>/Stubs/<Tipo>+Stub.swift")
    func testOutputLayoutRelativePath() {
        let layout = OutputLayout(rootDirectory: "Tests/AppTests/Generated/")
        let nested = ModelDefinition(name: "User", filePath: "Sources/App/Data/Entities/User.swift", module: "App", relativeDirectory: "Data/Entities")
        let atRoot = ModelDefinition(name: "Token", filePath: "Sources/App/Token.swift", module: "App", relativeDirectory: "")

        #expect(layout.relativePath(for: nested) == "App/Data/Entities/Stubs/User+Stub.swift")
        #expect(layout.relativePath(for: atRoot) == "App/Stubs/Token+Stub.swift")
        #expect(layout.absolutePath(for: atRoot) == "Tests/AppTests/Generated/App/Stubs/Token+Stub.swift")
        #expect(nested.origin == "App/Data/Entities/User.swift")
    }

    @Test("CodeGenerator.generateFile emite un archivo autocontenido por modelo con su origen")
    func testGenerateFilePerModel() {
        let pet = ModelDefinition(name: "Pet", filePath: "Pet.swift", properties: [ModelProperty(name: "name", typeName: "String")], module: "App", relativeDirectory: "Data/Entities")
        let user = ModelDefinition(
            name: "User",
            filePath: "User.swift",
            properties: [ModelProperty(name: "name", typeName: "String"), ModelProperty(name: "pet", typeName: "Pet")],
            module: "App",
            relativeDirectory: "Data/Entities"
        )
        let code = CodeGenerator().generateFile(for: user, availableModels: ["Pet": pet, "User": user], imports: ["@testable import App"])

        #expect(code.hasPrefix("//\n//  User+Stub.swift"))
        #expect(code.contains("//  Origen: App/Data/Entities/User.swift"))
        #expect(code.contains("#if canImport(App)\n@testable import App\n#endif"))
        #expect(code.contains("extension User {"))
        #expect(code.contains("pet: Pet = .stub()"))
        #expect(!code.contains("extension Pet {"))
    }
}

// MARK: - Motor end-to-end

@Suite("SpockGenCore - Snapshots: generación, caché y deduplicación")
struct SpockGenSnapshotEngineTests {

    @Test("run() escribe un archivo por modelo reflejando la ruta de origen y resuelve autoTree")
    func testRunWritesMirroredLayout() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("import SpockSwift\n@testable import App\n\n@Stubbed\nextension User {}")

        let result = try fixture.engine(withCache: true).run()
        guard case .generated(let count, let directory) = result else {
            Issue.record("Se esperaba .generated, se obtuvo \(result)")
            return
        }

        #expect(count == 2) // User y Pet descubiertos
        #expect(directory == fixture.generated.path)
        #expect(fixture.generatedExists(SnapshotFixture.userStub))
        #expect(fixture.generatedExists(SnapshotFixture.petStub))

        let user = try fixture.generatedContent(SnapshotFixture.userStub)
        #expect(user.contains("extension User {"))
        #expect(user.contains("pet: Pet = .stub()"))
        #expect(user.contains("@testable import App"))
        #expect(!user.contains("extension Pet {"))

        let pet = try fixture.generatedContent(SnapshotFixture.petStub)
        #expect(pet.contains("extension Pet {"))
        #expect(pet.contains("name: String = \"dummy_name\""))
    }

    @Test("Segunda ejecución sin cambios es cache HIT y un duplicado en otro archivo no genera de más")
    func testCacheHitAndDuplicateDeclarations() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed\nextension User {}")
        let engine = fixture.engine(withCache: true)

        _ = try engine.run()
        let second = try engine.run()
        #expect(second == .upToDate(cachedModelsCount: 2))

        try fixture.writeTest("@Stubbed\nextension User {}", named: "ProfileTests.swift")
        let third = try engine.run()
        guard case .generated(let count, _) = third else {
            Issue.record("Se esperaba .generated, se obtuvo \(third)")
            return
        }
        #expect(count == 2)
        #expect(fixture.configuration().layout.existingGeneratedFiles() == [SnapshotFixture.petStub, SnapshotFixture.userStub])
    }

    @Test("Editar un stub generado a mano invalida la caché y run() lo restaura")
    func testManualEditIsRestored() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed\nextension User {}")
        let engine = fixture.engine(withCache: true)

        _ = try engine.run()
        try fixture.write("// editado a mano", to: fixture.generated.appendingPathComponent(SnapshotFixture.petStub))

        let result = try engine.run()
        guard case .generated = result else {
            Issue.record("Se esperaba .generated, se obtuvo \(result)")
            return
        }
        #expect(try fixture.generatedContent(SnapshotFixture.petStub).contains("extension Pet {"))
    }

    @Test("Un @Stubbed struct declarado en tests se genera bajo el módulo de tests")
    func testStubbedStructInTestsUsesTestModule() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("""
        import SpockSwift

        @Stubbed
        extension User {}

        @Stubbed
        struct LocalTestModel {
            var some: String
            var count: Int
        }
        """, named: "CombinedTests.swift")

        let result = try fixture.engine().run()
        guard case .generated(let count, _) = result else {
            Issue.record("Se esperaba .generated, se obtuvo \(result)")
            return
        }
        #expect(count == 3)

        let local = try fixture.generatedContent("AppTests/Stubs/LocalTestModel+Stub.swift")
        #expect(local.contains("//  Origen: AppTests/CombinedTests.swift"))
        #expect(local.contains("some: String = \"dummy_some\""))
        #expect(local.contains("count: Int = 0"))
    }

    @Test("El cleaner elimina stubs huérfanos y carpetas vacías cuando desaparece la declaración")
    func testCleanerRemovesOrphans() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed extension User {}")
        let engine = fixture.engine(withCache: true)

        _ = try engine.run()
        #expect(fixture.generatedExists(SnapshotFixture.userStub))

        try fixture.writeTest("// Sin anotaciones @Stubbed")
        let result = try engine.run()
        #expect(result == .noStubsFound)
        #expect(!fixture.generatedExists(SnapshotFixture.userStub))
        #expect(!fixture.generatedExists(SnapshotFixture.petStub))
        #expect(!FileManager.default.fileExists(atPath: fixture.generated.path))
    }

    @Test("Un modelo usado con .stub() sin anotar se descubre, y al cambiar el modelo el stub se actualiza")
    func testAutoDiscoverAndUpdateOnModelChange() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("""
        import Testing
        struct UserTests {
            @Test func testUser() {
                let user = User.stub()
                #expect(user.name == "dummy_name")
            }
        }
        """)
        let engine = fixture.engine()

        let first = try engine.run()
        guard case .generated(let count, _) = first else {
            Issue.record("Debió auto-descubrir User")
            return
        }
        #expect(count == 2)
        #expect(try fixture.generatedContent(SnapshotFixture.userStub).contains("name: String = \"dummy_name\""))

        try fixture.writeDomain(userHasEmail: true)
        _ = try engine.run()
        let updated = try fixture.generatedContent(SnapshotFixture.userStub)
        #expect(updated.contains("email: String = \"dummy_email\""))
    }
}

// MARK: - check y clean

@Suite("SpockGenCore - Snapshots: check detecta desfases y clean los borra")
struct SpockGenCheckTests {

    @Test("check() está al día tras generar y reporta faltantes, desfasados y huérfanos por separado")
    func testCheckReportsDrift() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed extension User {}")
        let engine = fixture.engine()

        // Antes de generar: todo falta
        let before = try engine.check()
        #expect(before.missing == [SnapshotFixture.petStub, SnapshotFixture.userStub])
        #expect(before.stale.isEmpty && before.orphaned.isEmpty)
        #expect(!before.isUpToDate)

        _ = try engine.run()
        #expect(try engine.check().isUpToDate)

        // El dominio cambia: el stub de User queda desfasado
        try fixture.writeDomain(userHasEmail: true)
        let stale = try engine.check()
        #expect(stale.stale == [SnapshotFixture.userStub])
        #expect(stale.missing.isEmpty)

        // Falta un archivo y sobra otro
        try FileManager.default.removeItem(at: fixture.generated.appendingPathComponent(SnapshotFixture.petStub))
        let orphan = "App/Stubs/Ghost+Stub.swift"
        try FileManager.default.createDirectory(at: fixture.generated.appendingPathComponent("App/Stubs"), withIntermediateDirectories: true)
        try fixture.write("// huérfano", to: fixture.generated.appendingPathComponent(orphan))

        let drift = try engine.check()
        #expect(drift.missing == [SnapshotFixture.petStub])
        #expect(drift.stale == [SnapshotFixture.userStub])
        #expect(drift.orphaned == [orphan])

        // run() reconcilia todo
        _ = try engine.run()
        #expect(try engine.check().isUpToDate)
        #expect(!fixture.generatedExists(orphan))
    }

    @Test("check() no escribe nada en disco")
    func testCheckIsReadOnly() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed extension User {}")

        _ = try fixture.engine().check()
        #expect(!FileManager.default.fileExists(atPath: fixture.generated.path))
    }

    @Test("clean() elimina los stubs generados y la caché, y devuelve lo que borró")
    func testCleanRemovesEverything() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed extension User {}")
        let engine = fixture.engine(withCache: true)

        _ = try engine.run()
        #expect(FileManager.default.fileExists(atPath: fixture.cache.path))

        let removed = try engine.clean()
        #expect(removed == [SnapshotFixture.petStub, SnapshotFixture.userStub])
        #expect(!FileManager.default.fileExists(atPath: fixture.generated.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.cache.path))
    }

    @Test("CacheManager valida la carpeta completa: manifiesto, hashes y ausencia de archivos extra")
    func testCacheManagerValidatesLayout() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Stubbed extension User {}")
        let engine = fixture.engine(withCache: true)
        _ = try engine.run()

        let manager = CacheManager(cacheFilePath: fixture.cache.path)
        let manifest = manager.loadManifest()
        #expect(manifest?.generatedFiles.keys.sorted() == [SnapshotFixture.petStub, SnapshotFixture.userStub])
        #expect(manifest?.generatedModels == ["Pet", "User"])

        let plan = try engine.plan()
        let layout = fixture.configuration().layout
        #expect(manager.isCacheValid(for: plan.inputFiles, layout: layout, cachedManifest: manifest))

        let extraDirectory = fixture.generated.appendingPathComponent("App/Stubs")
        try FileManager.default.createDirectory(at: extraDirectory, withIntermediateDirectories: true)
        try fixture.write("// extra", to: extraDirectory.appendingPathComponent("Extra+Stub.swift"))
        #expect(!manager.isCacheValid(for: plan.inputFiles, layout: layout, cachedManifest: manifest))
    }
}

// MARK: - Utilidades que se conservan

@Suite("SpockGenCore - Utilidades")
struct SpockGenUtilityTests {

    @Test("SyntaxValidator detecta errores de sintaxis en Swift incompleto")
    func testSyntaxValidatorDetectsErrors() {
        let incompleteCode = "struct User { var name: "
        #expect(SyntaxValidator.hasSyntaxErrors(source: incompleteCode) == true)

        let validCode = "struct User { var name: String }"
        #expect(SyntaxValidator.hasSyntaxErrors(source: validCode) == false)
    }

    @Test("XcodeProjectIntegrator resuelve el project.pbxproj a través de un .xcworkspace")
    func testFindXcodeProjectThroughWorkspace() {
        let foundPath = XcodeProjectIntegrator.findXcodeProject(nearPath: "Example/ExampleTests/Generated")
        #expect(foundPath != nil)
        #expect(foundPath?.hasSuffix("Example/Example.xcodeproj/project.pbxproj") == true)
    }

    @Test("DaemonManager gestiona archivo PID y estado del proceso")
    func testDaemonManagerLifecycle() throws {
        let tempPidFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).pid")
        let tempLogFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).log")
        defer {
            try? FileManager.default.removeItem(at: tempPidFile)
            try? FileManager.default.removeItem(at: tempLogFile)
        }

        let manager = DaemonManager(pidFilePath: tempPidFile.path, logFilePath: tempLogFile.path)
        #expect(manager.status().isRunning == false)

        let currentPid = ProcessInfo.processInfo.processIdentifier
        try manager.savePid(currentPid)

        let activeStatus = manager.status()
        #expect(activeStatus.isRunning == true)
        #expect(activeStatus.pid == currentPid)
        #expect(manager.readPid() == currentPid)

        manager.removePidFile()
        #expect(manager.status().isRunning == false)
    }

    @Test("CacheManager deserializa manifiestos antiguos sin generatedFiles")
    func testCacheManifestBackwardCompatibility() throws {
        let legacyJson = """
        {
            "version": "2.0.0",
            "fileHashes": { "Old.swift": "oldHash" },
            "outputHash": "outHash",
            "generatedModels": ["User"]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SpockCacheManifest.self, from: legacyJson)
        #expect(decoded.generatedModels == ["User"])
        #expect(decoded.generatedFiles.isEmpty)
        #expect(decoded.fileHashes["Old.swift"] == "oldHash")
    }
}
