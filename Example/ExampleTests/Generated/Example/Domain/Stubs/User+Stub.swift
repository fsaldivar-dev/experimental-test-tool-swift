//
//  User+Stub.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/User.swift
//  Si el modelo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
#if canImport(Example)
@testable import Example
#endif

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
