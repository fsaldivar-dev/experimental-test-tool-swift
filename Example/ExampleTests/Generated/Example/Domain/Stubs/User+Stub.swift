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
        name: String = "Ana García",
        email: String = "ana.garcia@example.com",
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

    /// `count` instancias con identidad distinta: los identificadores incrementan y los textos llevan el índice.
    public static func stubs(count: Int) -> [User] {
        (0..<max(count, 0)).map { offset in
            let index = offset + 1
            return User.stub(
                id: index,
                name: "Ana García \(index)",
                email: "ana.garcia\(index)@example.com"
            )
        }
    }
}
