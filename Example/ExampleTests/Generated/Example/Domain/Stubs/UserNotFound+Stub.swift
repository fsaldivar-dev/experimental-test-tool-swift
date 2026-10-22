//
//  UserNotFound+Stub.swift
//  Generado por spock-gen (SpockSwift 2). No editar a mano.
//
//  Origen: Example/Domain/UserService.swift
//  Si el modelo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.
//

import Foundation
#if canImport(Example)
@testable import Example
#endif

extension UserNotFound {
    public static func stub(
        id: Int = 1
    ) -> UserNotFound {
        UserNotFound(
            id: id
        )
    }

    /// `count` instancias con identidad distinta: los identificadores incrementan y los textos llevan el índice.
    public static func stubs(count: Int) -> [UserNotFound] {
        (0..<max(count, 0)).map { offset in
            let index = offset + 1
            return UserNotFound.stub(
                id: index
            )
        }
    }
}
