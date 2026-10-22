//
//  UserService.swift
//  ExampleDomain
//
//  Created for SpockSwift 2 Example.
//

import Foundation

public protocol UserRepositoryProtocol: Sendable {
    func fetchUser(id: Int) async throws -> User
    func saveUser(_ user: User) async throws -> Bool
}

public final class UserService: Sendable {
    private let repository: UserRepositoryProtocol

    public init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    public func getUserDisplayName(id: Int) async throws -> String {
        let user = try await repository.fetchUser(id: id)
        return "\(user.name) (\(user.role.rawValue))"
    }

    public func updateBio(id: Int, newBio: String) async throws -> Bool {
        var user = try await repository.fetchUser(id: id)
        user.profile.bio = newBio
        return try await repository.saveUser(user)
    }
}

public struct UserNotFound: Error, Equatable {
    public let id: Int
    public init(id: Int) { self.id = id }
}

/// Repositorio real en memoria. En los tests se espía con `@Spied extension InMemoryUserRepository {}`.
public final class InMemoryUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private var storage: [Int: User]

    public init(users: [User] = []) {
        storage = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    public func fetchUser(id: Int) async throws -> User {
        guard let user = storage[id] else { throw UserNotFound(id: id) }
        return user
    }

    public func saveUser(_ user: User) async throws -> Bool {
        storage[user.id] = user
        return true
    }
}
