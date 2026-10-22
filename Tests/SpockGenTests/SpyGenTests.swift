//
//  SpyGenTests.swift
//  SpockGenTests
//
//  @Spied: spock-gen lee una implementación real y genera <Tipo>Spy, un envoltorio que conforma a
//  sus protocolos, registra cada llamada y siempre delega. Solo espía, no mockea.
//

import Testing
import Foundation
@testable import SpockGenCore

@Suite("SpockGenCore - Spies: parser de implementaciones")
struct ImplementationParserTests {

    @Test("ModelParser extrae clases, actores, structs y extensiones con sus métodos no privados")
    func testParsesImplementations() {
        let source = """
        public final class InMemoryUserRepository: UserRepositoryProtocol, @unchecked Sendable {
            private var storage: [Int: User] = [:]
            public init() {}
            public func fetchUser(id: Int) async throws -> User { storage[id]! }
            private func cache(_ user: User) {}
            fileprivate func dump() {}
            static func shared() -> InMemoryUserRepository { .init() }
            func update(_ value: inout Int) { value += 1 }
            func sum(_ values: Int...) -> Int { values.reduce(0, +) }
        }
        actor Cache { func get(_ key: String) -> String? { nil } }
        struct Point { var x: Int; func moved(by dx: Int) -> Point { Point(x: x + dx) } }
        extension InMemoryUserRepository: Auditable {
            func audit() {}
        }
        """
        let parsed = ModelParser.parseAll(source: source, filePath: "Repo.swift", module: "App", relativeDirectory: "Data")
        #expect(parsed.implementations.map(\.name) == ["InMemoryUserRepository", "Cache", "Point", "InMemoryUserRepository"])
        #expect(parsed.implementations.map(\.kind) == [.class, .actor, .struct, .extension])

        let repo = parsed.implementations[0]
        #expect(repo.inheritedTypes == ["UserRepositoryProtocol", "@unchecked Sendable"])
        #expect(repo.methods.map(\.name) == ["fetchUser", "shared", "update", "sum"], "init y métodos privados quedan fuera")
        #expect(repo.origin == "App/Data/Repo.swift")

        let update = repo.methods[2]
        #expect(update.parameters[0].isInout)
        #expect(update.parameters[0].typeName == "Int")
        #expect(update.parameters[0].forwardingText == "&value")

        let sum = repo.methods[3]
        #expect(sum.parameters[0].isVariadic)

        let ext = parsed.implementations[3]
        #expect(ext.inheritedTypes == ["Auditable"])
        #expect(ext.methods.map(\.name) == ["audit"])

        let merged = repo.merging(extensions: [ext])
        #expect(merged.inheritedTypes.contains("Auditable"))
        #expect(merged.methods.map(\.name).contains("audit"))
    }

    @Test("TestScanner registra @Spied sobre extensiones y tipos declarados en tests")
    func testScannerDetectsSpied() {
        let source = """
        @Spied extension InMemoryUserRepository {}
        @Spied final class LocalThing { func ping() {} }
        @Mocking extension Other {}
        """
        let stubs = TestScanner.scan(source: source)
        #expect(stubs.map { "\($0.typeName):\($0.kind.rawValue)" } == ["InMemoryUserRepository:spy", "LocalThing:spy", "Other:mock"])
    }
}

@Suite("SpockGenCore - Spies: SpyGenerator")
struct SpyGeneratorTests {

    @Test("Nombres: tipo del espía y propiedad envuelta en lowerCamel")
    func testNames() {
        #expect(SpyGenerator.spyTypeName(for: "InMemoryUserRepository") == "InMemoryUserRepositorySpy")
        #expect(SpyGenerator.wrappedPropertyName(for: "InMemoryUserRepository") == "inMemoryUserRepository")
        #expect(SpyGenerator.wrappedPropertyName(for: "URLSession") == "urlSession")
        #expect(SpyGenerator.wrappedPropertyName(for: "API") == "api")
    }

    private var repositoryProtocol: ProtocolDefinition {
        ProtocolDefinition(
            name: "UserRepositoryProtocol",
            methods: [
                MethodRequirement(name: "fetchUser", parameters: [ParameterDefinition(label: "id", name: "id", declaredType: "Int")], returnType: "User", isAsync: true, isThrows: true),
                MethodRequirement(name: "saveUser", parameters: [ParameterDefinition(label: nil, name: "user", declaredType: "User")], returnType: "Bool", isAsync: true, isThrows: true),
                MethodRequirement(name: "clear"),
                MethodRequirement(name: "shared", returnType: "Int", isStatic: true)
            ],
            properties: [
                PropertyRequirement(name: "count", typeName: "Int"),
                PropertyRequirement(name: "name", typeName: "String", isSettable: true)
            ]
        )
    }

    @Test("Con protocolos conocidos, el espía conforma a ellos, reenvía cada requisito y registra antes de delegar")
    func testGeneratesProtocolSpy() {
        let implementation = ImplementationDefinition(name: "InMemoryUserRepository", filePath: "Repo.swift", module: "App", relativeDirectory: "Data", inheritedTypes: ["UserRepositoryProtocol", "Sendable"])
        let code = SpyGenerator().generateFile(for: implementation, conforming: [repositoryProtocol], imports: ["@testable import App"])

        #expect(code.hasPrefix("//\n//  InMemoryUserRepository+Spy.swift"))
        #expect(code.contains("//  Origen: App/Data/Repo.swift"))
        #expect(code.contains("import Foundation\nimport SpockSwift\n#if canImport(App)\n@testable import App\n#endif"))
        #expect(code.contains("final class InMemoryUserRepositorySpy: UserRepositoryProtocol, SpockMock, @unchecked Sendable {"))

        #expect(code.contains("""
            struct Calls {
                let fetchUser = SpiedCall<Int>()
                let saveUser = SpiedCall<User>()
                let clear = SpiedCall<()>()
            }
            let calls = Calls()

            struct StaticCalls {
                let shared = SpiedCall<()>()
            }
            static let staticCalls = StaticCalls()

            var inMemoryUserRepository: InMemoryUserRepository

            init(_ inMemoryUserRepository: InMemoryUserRepository) {
                self.inMemoryUserRepository = inMemoryUserRepository
            }
        """))

        #expect(code.contains("    var count: Int { inMemoryUserRepository.count }"))
        #expect(code.contains("    var name: String {\n        get { inMemoryUserRepository.name }\n        set { inMemoryUserRepository.name = newValue }\n    }"))

        #expect(code.contains("    func fetchUser(id: Int) async throws -> User {\n        calls.fetchUser.record(id)\n        return try await inMemoryUserRepository.fetchUser(id: id)\n    }"))
        #expect(code.contains("    func saveUser(_ user: User) async throws -> Bool {\n        calls.saveUser.record(user)\n        return try await inMemoryUserRepository.saveUser(user)\n    }"))
        #expect(code.contains("    func clear() {\n        calls.clear.record(())\n        inMemoryUserRepository.clear()\n    }"))
        #expect(code.contains("    static func shared() -> Int {\n        Self.staticCalls.shared.record(())\n        return InMemoryUserRepository.shared()\n    }"))

        #expect(!code.contains("whenCall"), "un espía no se programa")
        #expect(!code.contains("MockedCall"))
    }

    @Test("Sin protocolos conocidos, espía los métodos del propio tipo y no declara conformancia")
    func testGeneratesPlainSpy() {
        let implementation = ImplementationDefinition(
            name: "Formatter",
            methods: [
                MethodRequirement(name: "format", parameters: [ParameterDefinition(label: nil, name: "value", declaredType: "Double"), ParameterDefinition(label: "decimals", name: "decimals", declaredType: "Int")], returnType: "String"),
                MethodRequirement(name: "bump", parameters: [ParameterDefinition(label: nil, name: "value", declaredType: "inout Int", typeName: "Int", isInout: true)]),
                MethodRequirement(name: "each", parameters: [ParameterDefinition(label: nil, name: "body", declaredType: "() -> Void", isNonEscapingClosure: true)]),
                MethodRequirement(name: "sum", parameters: [ParameterDefinition(label: nil, name: "values", declaredType: "Int...", typeName: "[Int]", isVariadic: true)], returnType: "Int"),
                MethodRequirement(name: "map", returnType: "Int", isGeneric: true)
            ]
        )
        let code = SpyGenerator().generateFile(for: implementation, conforming: [])

        #expect(code.contains("final class FormatterSpy: SpockMock, @unchecked Sendable {"))
        #expect(code.contains("let format = SpiedCall<(value: Double, decimals: Int)>()"))
        #expect(code.contains("    func format(_ value: Double, decimals: Int) -> String {\n        calls.format.record((value: value, decimals: decimals))\n        return formatter.format(value, decimals: decimals)\n    }"))
        // inout: se registra una copia y se reenvía con &
        #expect(code.contains("let bump = SpiedCall<Int>()"))
        #expect(code.contains("        calls.bump.record(value)\n        formatter.bump(&value)"))
        // closure no escaping: no se guarda, queda como Void
        #expect(code.contains("let each = SpiedCall<Void>()"))
        #expect(code.contains("        calls.each.record(())\n        formatter.each(body)"))
        // variádicos y genéricos se omiten con aviso
        #expect(!code.contains("let sum ="))
        #expect(code.contains("// sum(_:) no se espía: tiene parámetros variádicos"))
        #expect(code.contains("// map() no se espía: es genérico."))
    }
}

@Suite("SpockGenCore - Spies: motor end-to-end")
struct SpyEngineTests {

    static let spyFile = "App/Data/Services/Spies/InMemoryUserRepository+Spy.swift"

    private func writeRepository(_ fixture: SnapshotFixture, conformsViaExtension: Bool = false) throws {
        let services = fixture.sources.appendingPathComponent("Data/Services")
        try FileManager.default.createDirectory(at: services, withIntermediateDirectories: true)
        let conformance = conformsViaExtension ? "" : ": UserRepository"
        let ext = conformsViaExtension ? "\nextension InMemoryUserRepository: UserRepository {}" : ""
        try fixture.write("""
        public protocol UserRepository: Sendable {
            func fetchUser(id: Int) async throws -> User
            func saveUser(_ user: User) async throws -> Bool
        }
        public final class InMemoryUserRepository\(conformance) {
            private var storage: [Int: User] = [:]
            public init() {}
            public func fetchUser(id: Int) async throws -> User { storage[id]! }
            public func saveUser(_ user: User) async throws -> Bool { true }
            func helper() {}
        }\(ext)
        """, to: services.appendingPathComponent("UserRepository.swift"))
    }

    @Test("@Spied genera el espía bajo Spies/, conforme al protocolo del dominio, y no genera stubs")
    func testSpiedGeneratesSpy() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try writeRepository(fixture)
        try fixture.writeTest("import SpockSwift\n@testable import App\n\n@Spied\nextension InMemoryUserRepository {}")

        let engine = fixture.engine()
        let result = try engine.run()
        guard case .generated(let count, _) = result else {
            Issue.record("Se esperaba .generated, se obtuvo \(result)")
            return
        }
        #expect(count == 1)
        #expect(fixture.configuration().layout.existingGeneratedFiles() == [SpyEngineTests.spyFile], "un espía no necesita stubs")

        let spy = try fixture.generatedContent(SpyEngineTests.spyFile)
        #expect(spy.contains("final class InMemoryUserRepositorySpy: UserRepository, SpockMock, @unchecked Sendable {"))
        #expect(spy.contains("let fetchUser = SpiedCall<Int>()"))
        #expect(spy.contains("return try await inMemoryUserRepository.fetchUser(id: id)"))
        #expect(!spy.contains("helper"), "solo los requisitos del protocolo")
        #expect(spy.contains("@testable import App"))
        #expect(try engine.check().isUpToDate)
    }

    @Test("La conformancia declarada en una extensión también cuenta")
    func testConformanceViaExtension() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try writeRepository(fixture, conformsViaExtension: true)
        try fixture.writeTest("@Spied extension InMemoryUserRepository {}")

        _ = try fixture.engine().run()
        let spy = try fixture.generatedContent(SpyEngineTests.spyFile)
        #expect(spy.contains("final class InMemoryUserRepositorySpy: UserRepository, SpockMock, @unchecked Sendable {"))
    }

    @Test("@Spied sobre un tipo inexistente avisa y no genera nada")
    func testUnknownTypeWarns() throws {
        let fixture = try SnapshotFixture()
        defer { fixture.tearDown() }
        try fixture.writeDomain()
        try fixture.writeTest("@Spied extension Ghost {}")

        let plan = try fixture.engine().plan()
        #expect(plan.files.isEmpty)
        #expect(plan.warnings.count == 1)
        #expect(plan.warnings[0].contains("Ghost"))
    }
}
