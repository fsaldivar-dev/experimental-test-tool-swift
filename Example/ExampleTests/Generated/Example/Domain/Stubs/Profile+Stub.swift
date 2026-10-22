//
//  Profile+Stub.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/User.swift
//  Si el modelo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
#if canImport(Example)
@testable import Example
#endif

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
