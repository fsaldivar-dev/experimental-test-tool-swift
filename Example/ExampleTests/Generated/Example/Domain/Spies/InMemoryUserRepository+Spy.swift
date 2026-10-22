//
//  InMemoryUserRepository+Spy.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/UserService.swift
//  Si el tipo o sus protocolos cambian, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
import SpockSwift
#if canImport(Example)
@testable import Example
#endif

/// Espía de `InMemoryUserRepository`: registra cada llamada y delega en la implementación real.
final class InMemoryUserRepositorySpy: UserRepositoryProtocol, SpockMock, @unchecked Sendable {

    struct Calls {
        let fetchUser = SpiedCall<Int>()
        let saveUser = SpiedCall<User>()
    }
    let calls = Calls()

    var inMemoryUserRepository: InMemoryUserRepository

    init(_ inMemoryUserRepository: InMemoryUserRepository) {
        self.inMemoryUserRepository = inMemoryUserRepository
    }

    func fetchUser(id: Int) async throws -> User {
        calls.fetchUser.record(id)
        return try await inMemoryUserRepository.fetchUser(id: id)
    }

    func saveUser(_ user: User) async throws -> Bool {
        calls.saveUser.record(user)
        return try await inMemoryUserRepository.saveUser(user)
    }
}
