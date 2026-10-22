//
//  MockingMacro.swift
//  SpockSwiftMacros
//
//  Created for SpockSwift 2.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct MockingMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Marcador sintáctico para Spock 2.
        // El mock lo escribe `spock-gen` en Generated/<Módulo>/<ruta>/Mocks/<Protocolo>+Mock.swift,
        // porque una macro sobre una extensión no ve los requisitos del protocolo.
        return []
    }
}
