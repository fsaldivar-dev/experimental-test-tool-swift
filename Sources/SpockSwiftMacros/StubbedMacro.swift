//
//  StubbedMacro.swift
//  SpockSwiftMacros
//
//  Created for SpockSwift 2.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct StubbedMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Marcador sintáctico para Spock 2.
        // La generación recursiva de código (.stub y autoTree) la realiza el prebuild CLI/plugin
        // para tener acceso completo al proyecto y no quedar limitado por el sandbox de la macro.
        return []
    }
}
