//
//  UserServiceMockTests.swift
//  ExampleTests
//
//  Created for SpockSwift 2 Example.
//

import Testing
import SpockSwift
@testable import Example

final class MockUserRepository: UserRepositoryProtocol, SpockMock, @unchecked Sendable {
    @Stubbed<Int, User>
    var fetchUserAction

    @Stubbed<User, Bool>
    var saveUserAction

    func fetchUser(id: Int) async throws -> User {
        try fetchUserAction.onCall(id) ?? .stub()
    }

    func saveUser(_ user: User) async throws -> Bool {
        try saveUserAction.onCall(user) ?? true
    }
}

@Suite("Example - SpockMock & Spy")
struct UserServiceMockTests {

    @Test("UserService llama al repositorio y retorna el nombre formateado")
    func testGetDisplayName() async throws {
        let mockRepo = MockUserRepository()
        let expectedUser = User.stub(name: "Jhonatan", role: .admin)

        mockRepo.fetchUserAction.whenRun { _ in
            expectedUser
        }

        let service = UserService(repository: mockRepo)
        let displayName = try await service.getUserDisplayName(id: 42)

        #expect(displayName == "Jhonatan (admin)")
        #expect(mockRepo.isInvoked(stub: { $0.fetchUserAction }))
        #expect(mockRepo.compare(stub: { $0.fetchUserAction }, to: 42))
    }

    @Test("UserService actualiza el bio del usuario correctamente")
    func testUpdateBio() async throws {
        let mockRepo = MockUserRepository()
        let initialUser = User.stub(name: "Francisco", profile: .stub(bio: "Original"))

        mockRepo.fetchUserAction.whenRun { _ in
            initialUser
        }
        mockRepo.saveUserAction.whenRun { _ in
            true
        }

        let service = UserService(repository: mockRepo)
        let success = try await service.updateBio(id: 10, newBio: "Updated Bio")

        #expect(success == true)
        #expect(mockRepo.isInvoked(stub: { $0.saveUserAction }))
        #expect(mockRepo.saveUserAction.getSpy().parameter?.profile.bio == "Updated Bio")
    }
}
