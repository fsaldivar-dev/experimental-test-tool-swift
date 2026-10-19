//
//  StubMarker.swift
//  SpockSwift
//
//  Created for SpockSwift 2.
//

import Foundation

/// Marcador sintáctico para Spock 2.
/// Se coloca sobre extensiones de modelos en tus tests para indicar al generador prebuild
/// que debe generar la función `.stub(...)` y resolver su árbol de dependencias (`autoTree`):
///
/// ```swift
/// @Stub
/// extension User {}
/// ```
@attached(member, names: arbitrary)
public macro Stub() = #externalMacro(module: "SpockSwiftMacros", type: "StubMacro")
