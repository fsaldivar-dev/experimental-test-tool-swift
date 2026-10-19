//
//  ModelParser.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Analizador de sintaxis de Swift que extrae la definición de structs y enums en Sources/.
public final class ModelParser: SyntaxVisitor, @unchecked Sendable {
    private let filePath: String
    public private(set) var models: [ModelDefinition] = []

    public init(filePath: String = "") {
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }

    public static func parse(source: String, filePath: String = "") -> [ModelDefinition] {
        let sourceFile = Parser.parse(source: source)
        let parser = ModelParser(filePath: filePath)
        parser.walk(sourceFile)
        return parser.models
    }

    public static func parse(fileURL: URL) throws -> [ModelDefinition] {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return parse(source: source, filePath: fileURL.path)
    }

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let structName = node.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var properties: [ModelProperty] = []

        for member in node.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                // Ignorar variables estáticas o de clase
                let isStatic = varDecl.modifiers.contains { modifier in
                    modifier.name.text == "static" || modifier.name.text == "class"
                }
                guard !isStatic else { continue }

                for binding in varDecl.bindings {
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                    let propName = pattern.identifier.text.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Extraer anotación de tipo
                    var typeName = "Any"
                    var isOptional = false
                    if let typeAnnotation = binding.typeAnnotation {
                        let rawType = typeAnnotation.type.trimmedDescription
                        if rawType.hasSuffix("?") {
                            isOptional = true
                            typeName = String(rawType.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if rawType.hasPrefix("Optional<") && rawType.hasSuffix(">") {
                            isOptional = true
                            let start = rawType.index(rawType.startIndex, offsetBy: 9)
                            let end = rawType.index(before: rawType.endIndex)
                            typeName = String(rawType[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            typeName = rawType
                        }
                    }

                    let defaultVal = binding.initializer?.value.trimmedDescription

                    properties.append(ModelProperty(
                        name: propName,
                        typeName: typeName,
                        isOptional: isOptional,
                        defaultValue: defaultVal
                    ))
                }
            }
        }

        models.append(ModelDefinition(
            name: structName,
            filePath: filePath,
            isEnum: false,
            properties: properties
        ))

        return .skipChildren
    }

    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let enumName = node.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var cases: [String] = []

        for member in node.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in caseDecl.elements {
                    cases.append(element.name.text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        models.append(ModelDefinition(
            name: enumName,
            filePath: filePath,
            isEnum: true,
            enumCases: cases
        ))

        return .skipChildren
    }
}
