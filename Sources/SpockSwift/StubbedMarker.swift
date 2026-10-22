//
//  StubbedMarker.swift
//  SpockSwift
//
//  Created for SpockSwift 2.
//

import Foundation

/// Marcador sintáctico para Spock 2.
/// Se coloca sobre extensiones de modelos en tus tests para indicar a `spock-gen`
/// que debe generar la función `.stub(...)` y resolver su árbol de dependencias (`autoTree`):
///
/// ```swift
/// @Stubbed
/// extension User {}
/// ```
///
/// La macro no genera código: expande a nada. Los stubs los escribe `spock-gen`
/// en `Generated/<Módulo>/<ruta>/Stubs/<Tipo>+Stub.swift`, y se versionan junto a los tests.
@attached(member, names: arbitrary)
public macro Stubbed() = #externalMacro(module: "SpockSwiftMacros", type: "StubbedMacro")
