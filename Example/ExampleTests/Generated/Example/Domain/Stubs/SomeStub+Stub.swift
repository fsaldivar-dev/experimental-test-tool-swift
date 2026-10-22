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
        age: Int = 30
    ) -> SomeStub {
        SomeStub(
            named: named,
            age: age
        )
    }

    /// `count` instancias con identidad distinta: los identificadores incrementan y los textos llevan el índice.
    public static func stubs(count: Int) -> [SomeStub] {
        (0..<max(count, 0)).map { offset in
            let index = offset + 1
            return SomeStub.stub(
                named: "dummy_named_\(index)"
            )
        }
    }
}
