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
