//
//  SpockGenTests.swift
//  SpockGenTests
//
//  Created for SpockSwift 2.
//

import Testing
import Foundation
@testable import SpockGenCore

@Suite("SpockGenCore - Fase 2: Inspección y Deduplicación")
struct SpockGenPhase2Tests {

    @Test("ModelParser extrae structs y propiedades correctamente")
    func testModelParserExtractsStructs() {
        let source = """
        public struct User {
            public let id: UUID
            public var name: String
            public var age: Int?
            public static let standard = "none"
        }
        """

        let models = ModelParser.parse(source: source, filePath: "User.swift")
        #expect(models.count == 1)

        let user = models[0]
        #expect(user.name == "User")
        #expect(user.isEnum == false)
        #expect(user.properties.count == 3) // ignora static let standard

        #expect(user.properties[0].name == "id")
        #expect(user.properties[0].typeName == "UUID")
        #expect(user.properties[0].isOptional == false)

        #expect(user.properties[1].name == "name")
        #expect(user.properties[1].typeName == "String")
        #expect(user.properties[1].isOptional == false)

        #expect(user.properties[2].name == "age")
        #expect(user.properties[2].typeName == "Int")
        #expect(user.properties[2].isOptional == true)
    }

    @Test("ModelParser extrae Enums con sus casos")
    func testModelParserExtractsEnums() {
        let source = """
        public enum Role: String, Codable {
            case admin = "ADMIN"
            case member
            case guest
        }
        """

        let models = ModelParser.parse(source: source, filePath: "Role.swift")
        #expect(models.count == 1)

        let role = models[0]
        #expect(role.name == "Role")
        #expect(role.isEnum == true)
        #expect(role.enumCases == ["admin", "member", "guest"])
    }

    @Test("TestScanner detecta @Stub en extensiones y structs")
    func testTestScannerDetectsStubs() {
        let testFile = """
        import SpockSwift

        @Stub
        extension User {}

        @Stub
        extension Pet {}

        struct RegularTest {}
        """

        let stubs = TestScanner.scan(source: testFile, filePath: "UserTests.swift")
        #expect(stubs.count == 2)
        #expect(stubs[0].typeName == "User")
        #expect(stubs[0].declaredInFile == "UserTests.swift")
        #expect(stubs[1].typeName == "Pet")
        #expect(stubs[1].declaredInFile == "UserTests.swift")
    }

    @Test("SourceTracker detecta duplicados entre distintos archivos y los ignora")
    func testSourceTrackerDeduplicates() {
        let declarations = [
            StubDeclaration(typeName: "User", declaredInFile: "UserTests.swift"),
            StubDeclaration(typeName: "Pet", declaredInFile: "PetTests.swift"),
            StubDeclaration(typeName: "User", declaredInFile: "ProfileTests.swift") // 👈 Duplicado en otro archivo
        ]

        let tracker = SourceTracker()
        let result = tracker.process(declarations: declarations)

        #expect(result.activeStubs.count == 2)
        #expect(result.activeStubs["User"]?.declaredInFile == "UserTests.swift")
        #expect(result.activeStubs["Pet"]?.declaredInFile == "PetTests.swift")

        #expect(result.ignoredDuplicates.count == 1)
        #expect(result.ignoredDuplicates[0].typeName == "User")
        #expect(result.ignoredDuplicates[0].declaredInFile == "ProfileTests.swift")

        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains("UserTests.swift"))
        #expect(result.warnings[0].contains("ProfileTests.swift"))
    }
}

@Suite("SpockGenCore - Fase 3: autoTree y Default Values")
struct SpockGenPhase3Tests {

    @Test("DefaultValueProvider sintetiza valores inteligentes según el tipo")
    func testDefaultValueProvider() {
        let provider = DefaultValueProvider()
        let availableModels: [String: ModelDefinition] = [
            "Status": ModelDefinition(name: "Status", filePath: "Status.swift", isEnum: true, enumCases: ["active", "inactive"]),
            "Pet": ModelDefinition(name: "Pet", filePath: "Pet.swift", isEnum: false, properties: [])
        ]

        #expect(provider.defaultValue(for: ModelProperty(name: "name", typeName: "String"), availableModels: availableModels) == "\"dummy_name\"")
        #expect(provider.defaultValue(for: ModelProperty(name: "userId", typeName: "Int"), availableModels: availableModels) == "1")
        #expect(provider.defaultValue(for: ModelProperty(name: "count", typeName: "Int"), availableModels: availableModels) == "0")
        #expect(provider.defaultValue(for: ModelProperty(name: "isVerified", typeName: "Bool"), availableModels: availableModels) == "false")
        #expect(provider.defaultValue(for: ModelProperty(name: "id", typeName: "UUID"), availableModels: availableModels) == "UUID()")
        #expect(provider.defaultValue(for: ModelProperty(name: "createdAt", typeName: "Date"), availableModels: availableModels) == "Date()")
        #expect(provider.defaultValue(for: ModelProperty(name: "website", typeName: "URL"), availableModels: availableModels) == "URL(string: \"https://example.com\")!")
        #expect(provider.defaultValue(for: ModelProperty(name: "tags", typeName: "[String]"), availableModels: availableModels) == "[]")
        #expect(provider.defaultValue(for: ModelProperty(name: "nickname", typeName: "String", isOptional: true), availableModels: availableModels) == "nil")
        #expect(provider.defaultValue(for: ModelProperty(name: "status", typeName: "Status"), availableModels: availableModels) == ".active")
        #expect(provider.defaultValue(for: ModelProperty(name: "pet", typeName: "Pet"), availableModels: availableModels) == ".stub()")
    }

    @Test("AutoTreeResolver resuelve árbol de 3 niveles A -> B -> C automáticamente")
    func testAutoTreeCascading() {
        let models: [String: ModelDefinition] = [
            "Breed": ModelDefinition(name: "Breed", filePath: "Breed.swift", properties: [
                ModelProperty(name: "name", typeName: "String")
            ]),
            "Pet": ModelDefinition(name: "Pet", filePath: "Pet.swift", properties: [
                ModelProperty(name: "name", typeName: "String"),
                ModelProperty(name: "breed", typeName: "Breed")
            ]),
            "User": ModelDefinition(name: "User", filePath: "User.swift", properties: [
                ModelProperty(name: "name", typeName: "String"),
                ModelProperty(name: "pet", typeName: "Pet")
            ])
        ]

        let resolver = AutoTreeResolver()
        // El developer en los tests SOLO pidió User
        let result = resolver.resolve(rootTypes: ["User"], availableModels: models)

        // Debe generar los 3: Breed, Pet, User en orden topológico
        #expect(result.modelsToGenerate.count == 3)
        let generatedNames = result.modelsToGenerate.map { $0.name }
        #expect(generatedNames == ["Breed", "Pet", "User"])

        // Pet y Breed deben figurar en autoDiscoveredTypes
        #expect(result.autoDiscoveredTypes.contains("Pet"))
        #expect(result.autoDiscoveredTypes.contains("Breed"))
        #expect(result.detectedCycles.isEmpty)
    }

    @Test("AutoTreeResolver detecta ciclos infinitos sin crashear")
    func testAutoTreeCycleDetection() {
        let models: [String: ModelDefinition] = [
            "NodeA": ModelDefinition(name: "NodeA", filePath: "NodeA.swift", properties: [
                ModelProperty(name: "b", typeName: "NodeB")
            ]),
            "NodeB": ModelDefinition(name: "NodeB", filePath: "NodeB.swift", properties: [
                ModelProperty(name: "a", typeName: "NodeA") // 👈 Ciclo: A -> B -> A
            ])
        ]

        let resolver = AutoTreeResolver()
        let result = resolver.resolve(rootTypes: ["NodeA"], availableModels: models)

        #expect(result.detectedCycles.count > 0)
        #expect(result.detectedCycles[0].contains("NodeA -> NodeB -> NodeA"))
    }
}

@Suite("SpockGenCore - Fase 4: CodeGenerator")
struct SpockGenPhase4Tests {

    @Test("CodeGenerator genera extensiones limpias con .stub(...)")
    func testCodeGeneratorOutput() {
        let roleEnum = ModelDefinition(name: "Role", filePath: "Role.swift", isEnum: true, enumCases: ["admin", "guest"])
        let petModel = ModelDefinition(name: "Pet", filePath: "Pet.swift", properties: [
            ModelProperty(name: "name", typeName: "String")
        ])
        let userModel = ModelDefinition(name: "User", filePath: "User.swift", properties: [
            ModelProperty(name: "name", typeName: "String"),
            ModelProperty(name: "role", typeName: "Role"),
            ModelProperty(name: "pet", typeName: "Pet")
        ])

        let availableModels: [String: ModelDefinition] = [
            "Role": roleEnum,
            "Pet": petModel,
            "User": userModel
        ]

        let generator = CodeGenerator()
        let generatedCode = generator.generate(
            models: [petModel, userModel],
            availableModels: availableModels
        )

        // Verificar que Pet tiene su extension y .stub()
        #expect(generatedCode.contains("extension Pet {"))
        #expect(generatedCode.contains("public static func stub("))
        #expect(generatedCode.contains("name: String = \"dummy_name\""))

        // Verificar que User tiene su extension y encadena pet con .stub()
        #expect(generatedCode.contains("extension User {"))
        #expect(generatedCode.contains("role: Role = .admin"))
        #expect(generatedCode.contains("pet: Pet = .stub()"))

        // Los enums no deben tener bloque extension
        #expect(!generatedCode.contains("extension Role {"))
    }

    @Test("CodeGenerator maneja structs vacíos sin parámetros")
    func testCodeGeneratorEmptyStruct() {
        let emptyModel = ModelDefinition(name: "EmptyModel", filePath: "Empty.swift", properties: [])
        let generator = CodeGenerator()
        let code = generator.generate(models: [emptyModel], availableModels: ["EmptyModel": emptyModel])

        #expect(code.contains("extension EmptyModel {"))
        #expect(code.contains("public static func stub() -> EmptyModel {"))
        #expect(code.contains("EmptyModel()"))
    }
}

@Suite("SpockGenCore - Fase 5: CacheManager")
struct SpockGenPhase5Tests {

    @Test("CacheManager calcula SHA256 determinista")
    func testSHA256Computation() {
        let manager = CacheManager(cacheFilePath: "/tmp/dummy-cache.json")
        let hash1 = manager.hash(string: "hello world")
        let hash2 = manager.hash(string: "hello world")
        let hash3 = manager.hash(string: "different content")

        #expect(hash1 == hash2)
        #expect(hash1 != hash3)
        #expect(hash1 == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
    }

    @Test("CacheManager detecta caché válido e invalidación ante cambios")
    func testCacheInvalidation() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("ModelA.swift")
        let file2 = tempDir.appendingPathComponent("ModelB.swift")
        let cacheFile = tempDir.appendingPathComponent(".spock-cache.json")

        try "struct ModelA {}".write(to: file1, atomically: true, encoding: .utf8)
        try "struct ModelB {}".write(to: file2, atomically: true, encoding: .utf8)

        let manager = CacheManager(cacheFilePath: cacheFile.path)
        let manifest = manager.createManifest(
            filePaths: [file1.path, file2.path],
            generatedCode: "// Generated code"
        )
        try manager.saveManifest(manifest)

        let loadedManifest = manager.loadManifest()
        #expect(loadedManifest != nil)
        #expect(loadedManifest?.fileHashes.count == 2)

        // Cache válido sin cambios
        let isValid = manager.isCacheValid(
            for: [file1.path, file2.path],
            cachedManifest: loadedManifest
        )
        #expect(isValid == true)

        // Modificamos un archivo: debe invalidar el caché
        try "struct ModelA { var x: Int }".write(to: file1, atomically: true, encoding: .utf8)
        let isStillValid = manager.isCacheValid(
            for: [file1.path, file2.path],
            cachedManifest: loadedManifest
        )
        #expect(isStillValid == false)
    }
}

@Suite("SpockGenCore - Fase 6: SpockGenEngine End-to-End")
struct SpockGenPhase6Tests {

    @Test("SpockGenEngine orquesta inspección, autoTree, generación y caché correctamente")
    func testEngineEndToEnd() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourcesDir = tempDir.appendingPathComponent("Sources")
        let testsDir = tempDir.appendingPathComponent("Tests")
        let outputSwift = tempDir.appendingPathComponent("Generated/Stubs.generated.swift")
        let cacheJson = tempDir.appendingPathComponent(".spock-cache.json")

        try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)

        // 1. Modelos en Sources/
        let userModelContent = """
        struct Pet {
            var name: String
        }

        struct User {
            var id: Int
            var name: String
            var pet: Pet
        }
        """
        try userModelContent.write(to: sourcesDir.appendingPathComponent("User.swift"), atomically: true, encoding: .utf8)

        // 2. Test con @Stub en Tests/
        let testContent = """
        import SpockSwift

        @Stub
        extension User {}
        """
        try testContent.write(to: testsDir.appendingPathComponent("UserTests.swift"), atomically: true, encoding: .utf8)

        // 3. Ejecutar Engine por primera vez
        let config = SpockGenEngine.Configuration(
            sourcesDirectories: [sourcesDir.path],
            testsDirectories: [testsDir.path],
            outputPath: outputSwift.path,
            cachePath: cacheJson.path,
            verbose: false
        )
        let engine = SpockGenEngine(config: config)
        let firstResult = try engine.run()

        guard case .generated(let count, _) = firstResult else {
            Issue.record("Se esperaba .generated, se obtuvo \(firstResult)")
            return
        }

        #expect(count == 2) // User y Pet descubiertos
        #expect(FileManager.default.fileExists(atPath: outputSwift.path))

        let generatedCode = try String(contentsOf: outputSwift, encoding: .utf8)
        #expect(generatedCode.contains("extension User {"))
        #expect(generatedCode.contains("extension Pet {"))
        #expect(generatedCode.contains("pet: Pet = .stub()"))

        // 4. Ejecutar por segunda vez sin cambios: debe ser Cache HIT (.upToDate)
        let secondResult = try engine.run()
        guard case .upToDate = secondResult else {
            Issue.record("Se esperaba .upToDate por cache hit, se obtuvo \(secondResult)")
            return
        }

        // 5. Agregar un duplicado en otro archivo de tests: no debe crashear ni duplicar
        let duplicateTestContent = """
        import SpockSwift

        @Stub
        extension User {}
        """
        try duplicateTestContent.write(to: testsDir.appendingPathComponent("ProfileTests.swift"), atomically: true, encoding: .utf8)

        let thirdResult = try engine.run()
        guard case .generated(let countAfterDuplicate, _) = thirdResult else {
            Issue.record("Se esperaba .generated, se obtuvo \(thirdResult)")
            return
        }
        #expect(countAfterDuplicate == 2)
    }

    @Test("Engine genera stubs tanto para @Stub extension como para @Stub struct declarado en tests")
    func testEngineSupportsStubOnStructInTests() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourcesDir = tempDir.appendingPathComponent("Sources")
        let testsDir = tempDir.appendingPathComponent("Tests")
        let outputSwift = tempDir.appendingPathComponent("Generated/Stubs.generated.swift")

        try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)

        // 1. Modelo en Sources: User
        let userModel = "public struct User { public var name: String }"
        try userModel.write(to: sourcesDir.appendingPathComponent("User.swift"), atomically: true, encoding: .utf8)

        // 2. Tests con @Stub extension User Y @Stub struct LocalTestModel
        let testContent = """
        import SpockSwift

        @Stub
        extension User {}

        @Stub
        struct LocalTestModel {
            var some: String
            var count: Int
        }
        """
        try testContent.write(to: testsDir.appendingPathComponent("CombinedTests.swift"), atomically: true, encoding: .utf8)

        let config = SpockGenEngine.Configuration(
            sourcesDirectories: [sourcesDir.path],
            testsDirectories: [testsDir.path],
            outputPath: outputSwift.path,
            verbose: false
        )
        let engine = SpockGenEngine(config: config)
        let result = try engine.run()

        guard case .generated(let count, _) = result else {
            Issue.record("Se esperaba .generated, se obtuvo \(result)")
            return
        }

        #expect(count == 2)
        let generatedCode = try String(contentsOf: outputSwift, encoding: .utf8)
        #expect(generatedCode.contains("extension User {"))
        #expect(generatedCode.contains("extension LocalTestModel {"))
        #expect(generatedCode.contains("some: String = \"dummy_some\""))
        #expect(generatedCode.contains("count: Int = 0"))
    }

    @Test("SyntaxValidator detecta errores de sintaxis en Swift incompleto")
    func testSyntaxValidatorDetectsErrors() {
        let incompleteCode = "struct User { var name: "
        #expect(SyntaxValidator.hasSyntaxErrors(source: incompleteCode) == true)

        let validCode = "struct User { var name: String }"
        #expect(SyntaxValidator.hasSyntaxErrors(source: validCode) == false)
    }

    @Test("XcodeProjectIntegrator garantiza la existencia del archivo de stubs para evitar errores de manifest")
    func testEnsureGeneratedFileExists() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Stubs.generated.swift")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        #expect(!FileManager.default.fileExists(atPath: tempFile.path))
        XcodeProjectIntegrator.ensureGeneratedFileExists(atPath: tempFile.path)
        #expect(FileManager.default.fileExists(atPath: tempFile.path))

        let content = (try? String(contentsOf: tempFile, encoding: .utf8)) ?? ""
        #expect(content.contains("import Foundation"))
    }

    @Test("XcodeProjectIntegrator detecta cuando project.pbxproj ya está integrado")
    func testIntegrateAlreadyIntegrated() throws {
        let status = try XcodeProjectIntegrator.integrate(
            projectPbxprojPath: "Example/Example.xcodeproj/project.pbxproj",
            sourcesDir: "Example/Example/Domain",
            testsDir: "Example/ExampleTests"
        )
        #expect(status == .alreadyIntegrated)
    }

    @Test("XcodeProjectIntegrator resuelve el project.pbxproj a través de un .xcworkspace")
    func testFindXcodeProjectThroughWorkspace() {
        let foundPath = XcodeProjectIntegrator.findXcodeProject(nearPath: "Example/ExampleTests/Stubs.generated.swift")
        #expect(foundPath != nil)
        #expect(foundPath?.hasSuffix("Example/Example.xcodeproj/project.pbxproj") == true)
    }
}


