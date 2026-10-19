//
//  User.swift
//  ExampleDomain
//
//  Created for SpockSwift 2 Example.
//

import Foundation

public enum UserRole: String, CaseIterable, Sendable {
    case admin
    case member
    case guest
}

public struct Pet: Equatable, Sendable {
    public var name: String
    public var age: Int

    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}

public struct Profile: Equatable, Sendable {
    public var bio: String
    public var pet: Pet

    public init(bio: String, pet: Pet) {
        self.bio = bio
        self.pet = pet
    }
}

public struct User: Equatable, Sendable {
    public var id: Int
    public var name: String
    public var email: String
    public var role: UserRole
    public var profile: Profile

    public init(
        id: Int,
        name: String,
        email: String,
        role: UserRole,
        profile: Profile
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.profile = profile
    }
}
