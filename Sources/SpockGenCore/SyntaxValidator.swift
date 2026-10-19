//
//  SyntaxValidator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Valida si un archivo o fragmento de código Swift contiene errores de sintaxis incompletos.
public struct SyntaxValidator: Sendable {
    public static func hasSyntaxErrors(source: String) -> Bool {
        let tree = Parser.parse(source: source)
        return tree.hasError
    }

    public static func hasSyntaxErrors(fileURL: URL) -> Bool {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return true
        }
        return hasSyntaxErrors(source: content)
    }
}
