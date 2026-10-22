//
//  SomeStub+Stub.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/User.swift
//  Si el modelo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
#if canImport(Example)
@testable import Example
#endif

extension SomeStub {
    public static func stub(
        named: String = "dummy_named",
        age: Int = 0
    ) -> SomeStub {
        SomeStub(
            named: named,
            age: age
        )
    }
}
