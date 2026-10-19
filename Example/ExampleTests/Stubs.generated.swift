//
//  Stubs.generated.swift
//  SpockSwift 2 - Prebuild Generated Stubs
//
//  Generated automatically by spock-gen. Do not edit directly.
//

import Foundation
@testable import Example

extension TestCustomModel {
    public static func stub(
        some: String = "dummy_some"
    ) -> TestCustomModel {
        TestCustomModel(
            some: some
        )
    }
}

extension Pet {
    public static func stub(
        name: String = "dummy_name",
        age: Int = 0
    ) -> Pet {
        Pet(
            name: name,
            age: age
        )
    }
}

extension Profile {
    public static func stub(
        bio: String = "dummy_bio",
        pet: Pet = .stub()
    ) -> Profile {
        Profile(
            bio: bio,
            pet: pet
        )
    }
}

extension User {
    public static func stub(
        id: Int = 1,
        name: String = "dummy_name",
        email: String = "dummy_email",
        role: UserRole = .admin,
        profile: Profile = .stub()
    ) -> User {
        User(
            id: id,
            name: name,
            email: email,
            role: role,
            profile: profile
        )
    }
}

extension NewName {
    public static func stub(
        name: String = "dummy_name"
    ) -> NewName {
        NewName(
            name: name
        )
    }
}
