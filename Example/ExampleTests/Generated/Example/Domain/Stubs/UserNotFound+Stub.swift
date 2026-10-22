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
}
