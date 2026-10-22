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
