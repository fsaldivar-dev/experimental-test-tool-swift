//
//  TestScanner.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Escanea archivos en Tests/ buscando declaraciones marcadas con `@Stub`.
public final class TestScanner: SyntaxVisitor, @unchecked Sendable {
    private let filePath: String
    public private(set) var stubDeclarations: [StubDeclaration] = []

    public init(filePath: String = "") {
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }

    public static func scan(source: String, filePath: String = "") -> [StubDeclaration] {
        let sourceFile = Parser.parse(source: source)
        let scanner = TestScanner(filePath: filePath)
        scanner.walk(sourceFile)
        return scanner.stubDeclarations
    }

    public static func scan(fileURL: URL) throws -> [StubDeclaration] {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return scan(source: source, filePath: fileURL.path)
    }

    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasStubAttribute(node.attributes) {
            let typeName = node.extendedType.trimmedDescription
            stubDeclarations.append(StubDeclaration(
                typeName: typeName,
                declaredInFile: filePath
            ))
        }
        return .skipChildren
    }

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasStubAttribute(node.attributes) {
            let typeName = node.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
            stubDeclarations.append(StubDeclaration(
                typeName: typeName,
                declaredInFile: filePath
            ))
        }
        return .skipChildren
    }

    private func hasStubAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for element in attributes {
            if let attr = element.as(AttributeSyntax.self) {
                let attrName = attr.attributeName.trimmedDescription
                if attrName == "Stub" || attrName == "SpockSwift.Stub" {
                    return true
                }
            }
        }
        return false
    }
}
