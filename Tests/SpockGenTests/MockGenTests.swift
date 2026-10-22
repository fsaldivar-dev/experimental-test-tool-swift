//
//  MockGenTests.swift
//  SpockGenTests
//
//  @Mocking: spock-gen lee protocolos del dominio y genera mocks con una llamada mockeada por requisito
//  en Generated/<Módulo>/<ruta>/Mocks/<Protocolo>+Mock.swift.
//

import Testing
import Foundation
@testable import SpockGenCore

@Suite("SpockGenCore - Mocks: parser de protocolos")
struct ProtocolParserTests {

    @Test("ModelParser extrae métodos con parámetros, efectos, retorno y atributos")
    func testParsesMethods() {
        let source = """
        public protocol UserRepository: Sendable {
            func fetchUser(id: Int) async throws -> User
            func save(_ user: User, note: String?) -> Bool
            @MainActor func clear()
            static func shared() -> UserRepository
            func run(_ task: @escaping @Sendable () async throws -> Void)
            func sum(_ values: Int...) -> Int
            func map<T>(_ transform: (User) -> T) -> [T]
            func sync(_ body: () -> Void)
            func check(_ condition: @autoclosure () -> Bool)
            func later(_ handler: (() -> Void)?)
        }
        """
        let protocols = ModelParser.parseAll(source: source, filePath: "UserRepository.swift", module: "App", relativeDirectory: "Data/Services").protocols
        #expect(protocols.count == 1)
        let definition = protocols[0]
        #expect(definition.name == "UserRepository")
        #expect(definition.inheritedTypes == ["Sendable"])
        #expect(definition.origin == "App/Data/Services/UserRepository.swift")
        #expect(definition.methods.count == 10)

        let fetch = definition.methods[0]
        #expect(fetch.selector == "fetchUser(id:)")
        #expect(fetch.parameters == [ParameterDefinition(label: "id", name: "id", declaredType: "Int")])
        #expect(fetch.returnType == "User")
        #expect(fetch.isAsync && fetch.isThrows)

        let save = definition.methods[1]
        #expect(save.parameters[0].label == nil)
        #expect(save.parameters[0].name == "user")
        #expect(save.parameters[1].signatureText == "note: String?")
        #expect(save.returnType == "Bool")
        #expect(!save.isAsync && !save.isThrows)

        let clear = definition.methods[2]
        #expect(clear.attributes == ["@MainActor"])
        #expect(clear.returnType == nil)

        #expect(definition.methods[3].isStatic)

        let run = definition.methods[4]
        #expect(run.parameters[0].declaredType == "@escaping @Sendable () async throws -> Void")
        #expect(run.parameters[0].typeName == "@Sendable () async throws -> Void")
        #expect(!run.parameters[0].isNonEscapingClosure)

        let sum = definition.methods[5]
        #expect(sum.parameters[0].declaredType == "Int...")
        #expect(sum.parameters[0].typeName == "[Int]")

        #expect(definition.methods[6].isGeneric)

        // Closures sin @escaping, y @autoclosure, no se pueden guardar; los opcionales sí.
        #expect(definition.methods[7].parameters[0].isNonEscapingClosure)
        #expect(definition.methods[8].parameters[0].isNonEscapingClosure)
        #expect(definition.methods[8].parameters[0].typeName == "() -> Bool")
        #expect(!definition.methods[9].parameters[0].isNonEscapingClosure)
    }

    @Test("ModelParser extrae propiedades y marca requisitos no soportados")
    func testParsesPropertiesAndUnsupported() {
        let source = """
        protocol Session {
            var token: String { get }
            var retries: Int { get set }
            var user: User? { get }
            static var current: Session { get }
            associatedtype Payload
            init(token: String)
            subscript(index: Int) -> String { get }
        }
        """
        let definition = ModelParser.parseAll(source: source).protocols[0]
        #expect(definition.properties == [
            PropertyRequirement(name: "token", typeName: "String"),
            PropertyRequirement(name: "retries", typeName: "Int", isSettable: true),
            PropertyRequirement(name: "user", typeName: "User", isOptional: true),
            PropertyRequirement(name: "current", typeName: "Session", isStatic: true)
        ])
        #expect(definition.unsupportedRequirements == ["associatedtype", "init", "subscript"])
    }

    @Test("merging(parents:) añade los requisitos heredados sin repetir")
    func testMergingParents() {
        let parent = ProtocolDefinition(name: "Readable", methods: [MethodRequirement(name: "read", returnType: "String")], properties: [PropertyRequirement(name: "id", typeName: "Int")])
        let child = ProtocolDefinition(name: "Store", inheritedTypes: ["Readable"], methods: [MethodRequirement(name: "read", returnType: "String"), MethodRequirement(name: "write")])
        let merged = child.merging(parents: [parent])
        #expect(merged.methods.map(\.name) == ["read", "write"])
        #expect(merged.properties.map(\.name) == ["id"])
    }

    @Test("TestScanner distingue @Mocking de @Stubbed")
    func testScannerDetectsMocking() {
        let source = """
        import SpockSwift

        @Mocking
        extension UserRepository {}

        @Stubbed
        extension User {}

        @Mocking
        protocol LocalService { func ping() }
        """
        let stubs = TestScanner.scan(source: source, filePath: "Tests.swift")
        #expect(stubs.map { "\($0.typeName):\($0.kind.rawValue)" } == ["UserRepository:mock", "User:stub", "LocalService:mock"])
        #expect(stubs.allSatisfy { $0.isExplicit })
    }
}

@Suite("SpockGenCore - Mocks: MockGenerator")
struct MockGeneratorTests {

    private var user: ModelDefinition {
        ModelDefinition(name: "User", filePath: "User.swift", properties: [ModelProperty(name: "name", typeName: "String")], module: "App")
    }

    @Test("mockTypeName omite el sufijo Protocol y añade Mock")
    func testMockTypeName() {
        #expect(MockGenerator.mockTypeName(for: "UserRepositoryProtocol") == "UserRepositoryMock")
        #expect(MockGenerator.mockTypeName(for: "UserRepository") == "UserRepositoryMock")
        #expect(MockGenerator.mockTypeName(for: "Protocol") == "ProtocolMock")
    }

    @Test("Genera la tabla Calls y un cuerpo por método con la tupla de parámetros y el fallback del retorno")
    func testGeneratesCallsTable() {
        let definition = ProtocolDefinition(
            name: "UserRepositoryProtocol",
            filePath: "UserService.swift",
            module: "App",
            relativeDirectory: "Domain",
            methods: [
                MethodRequirement(name: "fetchUser", parameters: [ParameterDefinition(label: "id", name: "id", declaredType: "Int")], returnType: "User", isAsync: true, isThrows: true),
                MethodRequirement(name: "save", parameters: [ParameterDefinition(label: nil, name: "user", declaredType: "User"), ParameterDefinition(label: "note", name: "note", declaredType: "String?")], returnType: "Bool"),
                MethodRequirement(name: "find", parameters: [ParameterDefinition(label: "name", name: "name", declaredType: "String")], returnType: "User?", isThrows: true),
                MethodRequirement(name: "clear", attributes: ["@MainActor"]),
                MethodRequirement(name: "reset", isThrows: true)
            ],
            properties: [PropertyRequirement(name: "count", typeName: "Int", isSettable: true)]
        )

        let code = MockGenerator().generateFile(for: definition, availableModels: ["User": user], imports: ["@testable import App"])

        #expect(code.hasPrefix("//\n//  UserRepositoryProtocol+Mock.swift"))
        #expect(code.contains("//  Origen: App/Domain/UserService.swift"))
        #expect(code.contains("import Foundation\nimport SpockSwift\n#if canImport(App)\n@testable import App\n#endif"))
        #expect(code.contains("final class UserRepositoryMock: UserRepositoryProtocol, SpockMock, @unchecked Sendable {"))

        #expect(code.contains("""
            struct Calls {
                let fetchUser = MockedThrowingCall<Int, User>()
                let save = MockedCall<(user: User, note: String?), Bool>()
                let find = MockedThrowingCall<String, User>()
                let clear = MockedCall<(), Void>()
                let reset = MockedThrowingCall<(), Void>()
            }
            let calls = Calls()
        """))
        #expect(!code.contains("StaticCalls"))

        #expect(code.contains("    var count: Int = 3"))

        #expect(code.contains("    func fetchUser(id: Int) async throws -> User {\n        try calls.fetchUser.invoke(id) ?? .stub()\n    }"))
        #expect(code.contains("    func save(_ user: User, note: String?) -> Bool {\n        calls.save.invoke((user: user, note: note)) ?? false\n    }"))
        #expect(code.contains("    func find(name: String) throws -> User? {\n        try calls.find.invoke(name)\n    }"))
        #expect(code.contains("    @MainActor func clear() {\n        _ = calls.clear.invoke(())\n    }"))
        #expect(code.contains("    func reset() throws {\n        _ = try calls.reset.invoke(())\n    }"))
    }

    @Test("Closures no escaping se prestan con withoutActuallyEscaping y no se registran")
    func testNonEscapingClosures() {
        let definition = ProtocolDefinition(
            name: "Runner",
            methods: [
                MethodRequirement(name: "sync", parameters: [ParameterDefinition(label: nil, name: "body", declaredType: "() -> Void", isNonEscapingClosure: true)]),
                MethodRequirement(name: "measure", parameters: [
                    ParameterDefinition(label: "label", name: "label", declaredType: "String"),
                    ParameterDefinition(label: nil, name: "work", declaredType: "() throws -> Int", isNonEscapingClosure: true)
                ], returnType: "Int", isThrows: true),
                MethodRequirement(name: "observe", parameters: [ParameterDefinition(label: nil, name: "handler", declaredType: "@escaping (Int) -> Void", typeName: "(Int) -> Void")])
            ]
        )
        let code = MockGenerator().generateFile(for: definition, availableModels: [:])

        #expect(code.contains("let sync = MockedCall<() -> Void, Void>()"))
        #expect(code.contains("    func sync(_ body: () -> Void) {\n        _ = withoutActuallyEscaping(body) { body in calls.sync.invoke(body, recording: false) }\n    }"))
        #expect(code.contains("    func measure(label: String, _ work: () throws -> Int) throws -> Int {\n        try withoutActuallyEscaping(work) { work in try calls.measure.invoke((label: label, work: work), recording: false) ?? 0 }\n    }"))
        #expect(code.contains("let observe = MockedCall<(Int) -> Void, Void>()"))
        #expect(code.contains("    func observe(_ handler: @escaping (Int) -> Void) {\n        _ = calls.observe.invoke(handler)\n    }"))
    }

    @Test("Sobrecargas reciben nombres distintos; genéricos y estáticos se tratan aparte")
    func testOverloadsGenericsAndStatics() {
        let definition = ProtocolDefinition(
            name: "Search",
            methods: [
                MethodRequirement(name: "find", parameters: [ParameterDefinition(label: "id", name: "id", declaredType: "Int")], returnType: "String"),
                MethodRequirement(name: "find", parameters: [ParameterDefinition(label: "name", name: "name", declaredType: "String")], returnType: "String"),
                MethodRequirement(name: "map", returnType: "Int", isGeneric: true),
                MethodRequirement(name: "shared", returnType: "Int", isStatic: true)
            ]
        )
        let code = MockGenerator().generateFile(for: definition, availableModels: [:])

        #expect(code.contains("let findId = MockedCall<Int, String>()"))
        #expect(code.contains("let findName = MockedCall<String, String>()"))
        #expect(code.contains("fatalError(\"\\(Self.self).map() es genérico y no está mockeado\")"))
        #expect(!code.contains("let map ="))
        #expect(code.contains("    struct StaticCalls {\n        let shared = MockedCall<(), Int>()\n    }\n    static let staticCalls = StaticCalls()"))
        #expect(code.contains("    static func shared() -> Int {\n        SearchMock.staticCalls.shared.invoke(()) ?? 0\n    }"))
    }

    @Test("referencedTypes devuelve solo tipos nominales de retornos y propiedades")
    func testReferencedTypes() {
        let definition = ProtocolDefinition(
            name: "Repo",
            methods: [
                MethodRequirement(name: "a", returnType: "User"),
                MethodRequirement(name: "b", returnType: "[User]"),
                MethodRequirement(name: "c", returnType: "Profile?"),
                MethodRequirement(name: "d", returnType: "Result<User, Error>"),
                MethodRequirement(name: "e")
            ],
            properties: [PropertyRequirement(name: "pet", typeName: "Pet")]
        )
        #expect(MockGenerator.referencedTypes(in: definition) == ["User", "Profile", "Pet"])
    }
}

@Suite("SpockGenCore - Mocks: motor end-to-end")
struct MockEngineTests {

    static let mockFile = "App/Data/Services/Mocks/UserRepository+Mock.swift"

    private func writeService(_ fixture: SnapshotFixture, inherits: String = "Sendable") throws {
        let services = fixture.sources.appendingPathComponent("Data/Services")
        try FileManager.default.createDirectory(at: services, withIntermediateDirectories: true)
        try fixture.write("""
        public protocol Auditable {
            var lastEvent: String { get }
        }
        public protocol UserRepository: \(inherits) {
            func fetchUser(id: Int) async throws -> User
            func saveUser(_ user: User) async throws -> Bool
        }
        """, to: services.appendingPathComponent("UserRepository.swift"))
    }

    @Test("@Mocking genera el mock bajo Mocks/ y los stubs de los tipos que devuelve sin anotarlos")
    func testMockingGeneratesMockAndReturnStubs() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try writeService(fixture)
        try fixture.writeTest("import SpockSwift\n@testable import App\n\n@Mocking\nextension UserRepository {}")

        let engine = fixture.engine()
        let result = try engine.run()
        guard case .generated(let count, _) = result else {
            Issue.record("Se esperaba .generated, se obtuvo \(result)")
            return
        }
        #expect(count == 3) // User y Pet (stubs) + UserRepository (mock)

        #expect(fixture.generatedExists(MockEngineTests.mockFile))
        #expect(fixture.generatedExists(SnapshotFixture.userStub))
        #expect(fixture.generatedExists(SnapshotFixture.petStub))

        let mock = try fixture.generatedContent(MockEngineTests.mockFile)
        #expect(mock.contains("final class UserRepositoryMock: UserRepository, SpockMock, @unchecked Sendable {"))
        #expect(mock.contains("let fetchUser = MockedThrowingCall<Int, User>()"))
        #expect(mock.contains("try calls.fetchUser.invoke(id) ?? .stub()"))
        #expect(mock.contains("try calls.saveUser.invoke(user) ?? false"))
        #expect(mock.contains("@testable import App"))

        #expect(try engine.check().isUpToDate)
    }

    @Test("El mock incluye los requisitos de los protocolos padre conocidos")
    func testMockMergesParentProtocols() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try writeService(fixture, inherits: "Auditable, Sendable")
        try fixture.writeTest("@Mocking extension UserRepository {}")

        _ = try fixture.engine().run()
        let mock = try fixture.generatedContent(MockEngineTests.mockFile)
        #expect(mock.contains("var lastEvent: String = \"dummy_lastEvent\""))
        #expect(mock.contains("let fetchUser = MockedThrowingCall<Int, User>()"))
    }

    @Test("@Mocking sobre un protocolo inexistente avisa y no genera nada")
    func testUnknownProtocolWarns() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Mocking extension Ghost {}")

        let plan = try fixture.engine().plan()
        #expect(plan.files.isEmpty)
        #expect(plan.warnings.count == 1)
        #expect(plan.warnings[0].contains("Ghost"))
    }

    @Test("Al cambiar el protocolo, check marca el mock como desfasado y run lo actualiza")
    func testMockDriftIsDetected() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try writeService(fixture)
        try fixture.writeTest("@Mocking extension UserRepository {}")
        let engine = fixture.engine()
        _ = try engine.run()

        let services = fixture.sources.appendingPathComponent("Data/Services/UserRepository.swift")
        try fixture.write("public protocol UserRepository { func fetchUser(id: Int) async throws -> User; func delete(id: Int) throws }", to: services)

        let drift = try engine.check()
        #expect(drift.stale == [MockEngineTests.mockFile])
        _ = try engine.run()
        #expect(try fixture.generatedContent(MockEngineTests.mockFile).contains("let delete = MockedThrowingCall<Int, Void>()"))
        #expect(try engine.check().isUpToDate)
    }
}
