//
//  SpockGenTests.swift
//  SpockGenTests
//
//  Created for SpockSwift 2.
//

import Testing
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

