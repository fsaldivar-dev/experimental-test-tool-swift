//
//  UserServiceMockTests.swift
//  ExampleTests
//
//  Created for SpockSwift 2 Example.
//

import Testing
import SpockSwift
@testable import Example

// Anotación declarativa @Mocking:
// spock-gen genera UserRepositoryMock en Generated/Example/Domain/Mocks/UserRepositoryProtocol+Mock.swift,
// con una llamada mockeada por requisito y los stubs de los tipos que devuelve.

@Mocking
extension UserRepositoryProtocol {}

@Suite("Example - SpockMock & Spy")
struct UserServiceMockTests {

    @Test("UserService llama al repositorio y retorna el nombre formateado")
    func testGetDisplayName() async throws {
        let mockRepo = UserRepositoryMock()
        let expectedUser = User.stub(name: "Jhonatan", role: .admin)

        mockRepo.whenCall(\.fetchUser).returns(expectedUser)

        let service = UserService(repository: mockRepo)
        let displayName = try await service.getUserDisplayName(id: 42)

        #expect(displayName == "Jhonatan (admin)")
        #expect(mockRepo.verify(\.fetchUser).called(times: 1))
        #expect(mockRepo.verify(\.fetchUser).called(with: 42))
    }

    @Test("UserService actualiza el bio del usuario correctamente")
    func testUpdateBio() async throws {
        let mockRepo = UserRepositoryMock()
        let initialUser = User.stub(name: "Francisco", profile: .stub(bio: "Original"))

        mockRepo.whenCall(\.fetchUser).returns { id in
            initialUser
        }
        mockRepo.whenCall(\.saveUser).returns(true)

        let service = UserService(repository: mockRepo)
        let success = try await service.updateBio(id: 10, newBio: "Updated Bio")

        #expect(success == true)
        #expect(mockRepo.verify(\.saveUser).called())
        #expect(mockRepo.verify(\.saveUser).last?.profile.bio == "Updated Bio")
    }

    @Test("Un error programado en el repositorio llega al servicio")
    func testRepositoryErrorPropagates() async {
        struct Offline: Error {}
        let mockRepo = UserRepositoryMock()
        mockRepo.whenCall(\.fetchUser).throws(Offline())

        let service = UserService(repository: mockRepo)

        await #expect(throws: Offline.self) {
            try await service.getUserDisplayName(id: 1)
        }
        #expect(mockRepo.verify(\.fetchUser).called(with: 1))
    }
}

// MARK: - @Spied: la implementación real, registrada

// Anotación declarativa @Spied:
// spock-gen genera InMemoryUserRepositorySpy en Generated/Example/Domain/Spies/InMemoryUserRepository+Spy.swift.
// Conforma a UserRepositoryProtocol, envuelve la implementación real, registra cada llamada y siempre delega.
@Spied
extension InMemoryUserRepository {}

@Suite("Example - @Spied sobre una implementación real")
struct UserServiceSpyTests {

    @Test("El espía deja pasar al repositorio real y registra lo que pasó")
    func testSpyPassesThrough() async throws {
        let real = InMemoryUserRepository(users: [.stub(id: 10, name: "Francisco", profile: .stub(bio: "Original"))])
        let spy = InMemoryUserRepositorySpy(real)
        let service = UserService(repository: spy)

        let success = try await service.updateBio(id: 10, newBio: "Updated Bio")

        #expect(success == true)
        #expect(try await real.fetchUser(id: 10).profile.bio == "Updated Bio", "el real guardó el cambio")
        #expect(spy.verify(\.fetchUser).called(with: 10))
        #expect(spy.verify(\.saveUser).last?.profile.bio == "Updated Bio")
        #expect(spy.verify(\.saveUser).count == 1)
    }

    @Test("Los errores del real llegan tal cual a través del espía")
    func testSpyPropagatesRealErrors() async {
        let spy = InMemoryUserRepositorySpy(InMemoryUserRepository())

        await #expect(throws: UserNotFound(id: 99)) {
            try await UserService(repository: spy).getUserDisplayName(id: 99)
        }
        #expect(spy.verify(\.fetchUser).history == [99])
    }
}
