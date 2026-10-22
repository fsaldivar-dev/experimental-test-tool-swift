//
//  SpiedMacro.swift
//  SpockSwiftMacros
//
//  Created for SpockSwift 2.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct SpiedMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Marcador sintáctico para Spock 2.
        // El espía lo escribe `spock-gen` en Generated/<Módulo>/<ruta>/Spies/<Tipo>+Spy.swift,
        // porque una macro sobre una extensión no ve los métodos del tipo extendido.
        return []
    }
}
