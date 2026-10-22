//
//  Plugin.swift
//  SpockSwiftMacros
//
//  Created for SpockSwift 2.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SpockSwiftMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StubbedMacro.self,
        MockingMacro.self
    ]
}
