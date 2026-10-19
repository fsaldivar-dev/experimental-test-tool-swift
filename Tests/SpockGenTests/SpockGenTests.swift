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
