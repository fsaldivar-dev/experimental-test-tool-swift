//
//  TestScanner.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Escanea archivos de tests buscando declaraciones `@Stubbed` y `@Mocking` (explícitas),
/// llamadas a `.stub()` y modelos usados (implícitos).
///
/// Las explícitas tienen prioridad y solo entre ellas se reportan duplicados.
public final class TestScanner: SyntaxVisitor, @unchecked Sendable {
    private let filePath: String
    private let knownModelNames: Set<String>
    public private(set) var stubDeclarations: [StubDeclaration] = []
    public private(set) var importStatements: [String] = []

    public init(filePath: String = "", knownModelNames: Set<String> = []) {
        self.filePath = filePath
        self.knownModelNames = knownModelNames
        super.init(viewMode: .sourceAccurate)
    }

    public static func scan(
        source: String,
        filePath: String = "",
        knownModelNames: Set<String> = []
    ) -> [StubDeclaration] {
        scanDetailed(source: source, filePath: filePath, knownModelNames: knownModelNames).stubs
    }

    public static func scanDetailed(
        source: String,
        filePath: String = "",
        knownModelNames: Set<String> = []
    ) -> (stubs: [StubDeclaration], imports: [String]) {
        let sourceFile = Parser.parse(source: source)
        let scanner = TestScanner(filePath: filePath, knownModelNames: knownModelNames)
        scanner.walk(sourceFile)
        return (scanner.stubDeclarations, scanner.importStatements)
    }

    public static func scan(
        fileURL: URL,
        knownModelNames: Set<String> = []
    ) throws -> [StubDeclaration] {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return scan(source: source, filePath: fileURL.path, knownModelNames: knownModelNames)
    }

    private func register(typeName: String, explicit: Bool, kind: DeclarationKind = .stub) {
        let trimmed = typeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = stubDeclarations.firstIndex(where: { $0.typeName == trimmed }) {
            // Una declaración explícita reemplaza a un descubrimiento implícito del mismo archivo.
            if explicit, !stubDeclarations[index].isExplicit {
                stubDeclarations[index] = StubDeclaration(typeName: trimmed, declaredInFile: filePath, isExplicit: true, kind: kind)
            }
            return
        }
        stubDeclarations.append(StubDeclaration(
            typeName: trimmed,
            declaredInFile: filePath,
            isExplicit: explicit,
            kind: kind
        ))
    }

    public override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let importDesc = node.trimmedDescription
        if !importDesc.contains("SpockSwift") && !importDesc.contains("Testing") && !importDesc.contains("XCTest") {
            importStatements.append(importDesc)
        }
        return .skipChildren
    }

    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeName = node.extendedType.trimmedDescription
        if hasAttribute("Stubbed", in: node.attributes) {
            register(typeName: typeName, explicit: true, kind: .stub)
            return .skipChildren
        }
        if hasAttribute("Mocking", in: node.attributes) {
            register(typeName: typeName, explicit: true, kind: .mock)
            return .skipChildren
        }
        return .visitChildren
    }

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasAttribute("Stubbed", in: node.attributes) {
            register(typeName: node.name.text, explicit: true, kind: .stub)
            return .skipChildren
        }
        return .visitChildren
    }

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasAttribute("Mocking", in: node.attributes) {
            register(typeName: node.name.text, explicit: true, kind: .mock)
        }
        return .skipChildren
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Detectar llamadas <Type>.stub(...)
        if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
           memberAccess.declName.baseName.text == "stub" {
            if let base = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                let typeName = base.baseName.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !typeName.isEmpty, typeName.first?.isUppercase == true {
                    register(typeName: typeName, explicit: false)
                }
            } else if let memberBase = memberAccess.base?.as(MemberAccessExprSyntax.self) {
                let typeName = memberBase.declName.baseName.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !typeName.isEmpty, typeName.first?.isUppercase == true {
                    register(typeName: typeName, explicit: false)
                }
            }
        }
        return .visitChildren
    }

    public override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if knownModelNames.contains(name) {
            register(typeName: name, explicit: false)
        }
        return .skipChildren
    }

    public override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if knownModelNames.contains(name) {
            register(typeName: name, explicit: false)
        }
        return .visitChildren
    }

    private func hasAttribute(_ name: String, in attributes: AttributeListSyntax) -> Bool {
        for element in attributes {
            if let attr = element.as(AttributeSyntax.self) {
                let attrName = attr.attributeName.trimmedDescription
                if attrName == name || attrName == "SpockSwift.\(name)" {
                    return true
                }
            }
        }
        return false
    }
}
