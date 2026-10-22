//
//  UserRepositoryProtocol+Mock.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/UserService.swift
//  Si el protocolo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
import SpockSwift
#if canImport(Example)
@testable import Example
#endif

final class UserRepositoryMock: UserRepositoryProtocol, SpockMock, @unchecked Sendable {

    struct Calls {
        let fetchUser = MockedThrowingCall<Int, User>()
        let saveUser = MockedThrowingCall<User, Bool>()
    }
    let calls = Calls()

    func fetchUser(id: Int) async throws -> User {
        try calls.fetchUser.invoke(id) ?? .stub()
    }

    func saveUser(_ user: User) async throws -> Bool {
        try calls.saveUser.invoke(user) ?? false
    }
}
