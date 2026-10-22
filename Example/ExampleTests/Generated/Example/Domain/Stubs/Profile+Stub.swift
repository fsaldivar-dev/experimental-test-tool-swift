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
        bio: String = "Texto de ejemplo",
        pet: Pet = .stub()
    ) -> Profile {
        Profile(
            bio: bio,
            pet: pet
        )
    }

    /// `count` instancias con identidad distinta: los identificadores incrementan y los textos llevan el índice.
    public static func stubs(count: Int) -> [Profile] {
        (0..<max(count, 0)).map { offset in
            let index = offset + 1
            return Profile.stub(
                bio: "Texto de ejemplo \(index)"
            )
        }
    }
}
