//
//  SpiedMarker.swift
//  SpockSwift
//
//  Created for SpockSwift 2.
//

import Foundation

/// Marcador sintáctico para Spock 2.
/// Se coloca sobre una extensión de una implementación real en tus tests para indicar a `spock-gen`
/// que debe generar un espía: un envoltorio que conforma a los mismos protocolos, guarda la
/// implementación real, registra cada llamada y siempre delega en ella. Solo espía, no mockea.
///
/// ```swift
/// @Spied
/// extension InMemoryUserRepository {}
///
/// let spy = InMemoryUserRepositorySpy(InMemoryUserRepository(users: [.stub(id: 7)]))
/// _ = try await UserService(repository: spy).getUserDisplayName(id: 7)
/// #expect(spy.verify(\.fetchUser).called(with: 7))
/// ```
///
/// La macro no genera código: expande a nada. El espía lo escribe `spock-gen`
/// en `Generated/<Módulo>/<ruta>/Spies/<Tipo>+Spy.swift`, y se versiona junto a los tests.
@attached(member, names: arbitrary)
public macro Spied() = #externalMacro(module: "SpockSwiftMacros", type: "SpiedMacro")
