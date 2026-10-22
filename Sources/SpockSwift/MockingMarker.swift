//
//  MockingMarker.swift
//  SpockSwift
//
//  Created for SpockSwift 2.
//

import Foundation

/// Marcador sintáctico para Spock 2.
/// Se coloca sobre una extensión de un protocolo en tus tests para indicar a `spock-gen`
/// que debe generar un mock con una llamada mockeada por requisito:
///
/// ```swift
/// @Mocking
/// extension UserRepositoryProtocol {}
///
/// let repo = UserRepositoryMock()
/// repo.whenCall(\.fetchUser).returns(.stub(name: "Francisco"))
/// #expect(repo.verify(\.fetchUser).called(with: 7))
/// ```
///
/// La macro no genera código: expande a nada. El mock lo escribe `spock-gen`
/// en `Generated/<Módulo>/<ruta>/Mocks/<Protocolo>+Mock.swift`, y se versiona junto a los tests.
@attached(member, names: arbitrary)
public macro Mocking() = #externalMacro(module: "SpockSwiftMacros", type: "MockingMacro")
