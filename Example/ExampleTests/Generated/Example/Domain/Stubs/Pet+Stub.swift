//
//  Pet+Stub.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/User.swift
//  Si el modelo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
#if canImport(Example)
@testable import Example
#endif

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
