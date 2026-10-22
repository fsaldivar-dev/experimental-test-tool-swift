//
//  UserServiceMockTests.swift
//  ExampleTests
//
//  Created for SpockSwift 2 Example.
//
//  Cómo se escribe un test con SpockSwift 2:
//  - makeSUT construye el sistema bajo prueba con sus dobles y los devuelve con nombre.
//  - Cada test se lee en tres bloques: Given (dobles programados), When (una sola acción), Then (#expect).
//

import Testing
import SpockSwift
@testable import Example

// Anotación declarativa @Mocking:
// spock-gen genera UserRepositoryMock en Generated/Example/Domain/Mocks/UserRepositoryProtocol+Mock.swift,
// con una llamada mockeada por requisito y los stubs de los tipos que devuelve.
@Mocking
extension UserRepositoryProtocol {}

@Suite("Example - UserService con un mock")
struct UserServiceMockTests {

    /// El punto único donde se construye el SUT. Si cambia el init de UserService, cambia aquí y no en cada test.
    private func makeSUT() -> (sut: UserService, repo: UserRepositoryMock) {
        let repo = UserRepositoryMock()
        let sut = UserService(repository: repo)
        return (sut, repo)
    }

    @Test("Devuelve el nombre formateado del usuario que entrega el repositorio")
    func testGetDisplayName() async throws {
        // Given
        let (sut, repo) = makeSUT()
        repo.whenCall(\.fetchUser).returns(.stub(name: "Jhonatan", role: .admin))

        // When
        let displayName = try await sut.getUserDisplayName(id: 42)

        // Then
        #expect(displayName == "Jhonatan (admin)")
        #expect(repo.verify(\.fetchUser).called(times: 1))
        #expect(repo.verify(\.fetchUser).called(with: 42))
    }

    @Test("Actualiza el bio y guarda el usuario modificado")
    func testUpdateBio() async throws {
        // Given
        let (sut, repo) = makeSUT()
        repo.whenCall(\.fetchUser).returns { id in .stub(id: id, name: "Francisco", profile: .stub(bio: "Original")) }
        repo.whenCall(\.saveUser).returns(true)

        // When
        let success = try await sut.updateBio(id: 10, newBio: "Updated Bio")

        // Then
        #expect(success == true)
        let saved = try #require(repo.verify(\.saveUser).last)
        #expect(saved.id == 10)
        #expect(saved.profile.bio == "Updated Bio")
    }

    @Test("Un error programado en el repositorio llega al servicio sin transformarse")
    func testRepositoryErrorPropagates() async {
        // Given
        struct Offline: Error {}
        let (sut, repo) = makeSUT()
        repo.whenCall(\.fetchUser).throws(Offline())

        // When / Then
        await #expect(throws: Offline.self) {
            try await sut.getUserDisplayName(id: 1)
        }
        #expect(repo.verify(\.fetchUser).called(with: 1))
    }

    @Test("Formatea cualquier rol entre paréntesis", arguments: [UserRole.admin, .member, .guest])
    func testDisplayNameForEveryRole(role: UserRole) async throws {
        // Given
        let (sut, repo) = makeSUT()
        repo.whenCall(\.fetchUser).returns(.stub(name: "Ana", role: role))

        // When
        let displayName = try await sut.getUserDisplayName(id: 1)

        // Then
        #expect(displayName == "Ana (\(role.rawValue))")
    }
}

// MARK: - @Spied: la implementación real, registrada

// Anotación declarativa @Spied:
// spock-gen genera InMemoryUserRepositorySpy en Generated/Example/Domain/Spies/InMemoryUserRepository+Spy.swift.
// Conforma a UserRepositoryProtocol, envuelve la implementación real, registra cada llamada y siempre delega.
@Spied
extension InMemoryUserRepository {}

@Suite("Example - UserService con un espía sobre el repositorio real")
struct UserServiceSpyTests {

    /// Aquí el SUT usa la implementación real; el espía solo mira. Se devuelven los tres para el Then.
    private func makeSUT(users: [User] = []) -> (sut: UserService, spy: InMemoryUserRepositorySpy, real: InMemoryUserRepository) {
        let real = InMemoryUserRepository(users: users)
        let spy = InMemoryUserRepositorySpy(real)
        let sut = UserService(repository: spy)
        return (sut, spy, real)
    }

    @Test("El espía deja pasar al repositorio real y registra lo que pasó")
    func testSpyPassesThrough() async throws {
        // Given
        let (sut, spy, real) = makeSUT(users: [.stub(id: 10, name: "Francisco", profile: .stub(bio: "Original"))])

        // When
        let success = try await sut.updateBio(id: 10, newBio: "Updated Bio")

        // Then
        #expect(success == true)
        #expect(try await real.fetchUser(id: 10).profile.bio == "Updated Bio", "el real guardó el cambio")
        #expect(spy.verify(\.fetchUser).called(with: 10))
        #expect(spy.verify(\.saveUser).last?.profile.bio == "Updated Bio")
        #expect(spy.verify(\.saveUser).count == 1)
    }

    @Test("Los errores del real llegan tal cual a través del espía")
    func testSpyPropagatesRealErrors() async {
        // Given
        let (sut, spy, _) = makeSUT()

        // When / Then
        await #expect(throws: UserNotFound(id: 99)) {
            try await sut.getUserDisplayName(id: 99)
        }
        #expect(spy.verify(\.fetchUser).history == [99])
    }
}
