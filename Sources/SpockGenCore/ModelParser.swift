//
//  ModelParser.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Analizador de sintaxis de Swift que extrae structs, enums y protocolos de un archivo.
public final class ModelParser: SyntaxVisitor, @unchecked Sendable {
    private let filePath: String
    private let module: String
    private let relativeDirectory: String
    public private(set) var models: [ModelDefinition] = []
    public private(set) var protocols: [ProtocolDefinition] = []

    public init(filePath: String = "", module: String = "", relativeDirectory: String = "") {
        self.filePath = filePath
        self.module = module
        self.relativeDirectory = relativeDirectory
        super.init(viewMode: .sourceAccurate)
    }

    /// Structs y enums del archivo.
    public static func parse(
        source: String,
        filePath: String = "",
        module: String = "",
        relativeDirectory: String = ""
    ) -> [ModelDefinition] {
        parseAll(source: source, filePath: filePath, module: module, relativeDirectory: relativeDirectory).models
    }

    /// Structs, enums y protocolos del archivo.
    public static func parseAll(
        source: String,
        filePath: String = "",
        module: String = "",
        relativeDirectory: String = ""
    ) -> (models: [ModelDefinition], protocols: [ProtocolDefinition]) {
        let sourceFile = Parser.parse(source: source)
        let parser = ModelParser(filePath: filePath, module: module, relativeDirectory: relativeDirectory)
        parser.walk(sourceFile)
        return (parser.models, parser.protocols)
    }

    public static func parse(fileURL: URL, module: String = "", relativeDirectory: String = "") throws -> [ModelDefinition] {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return parse(source: source, filePath: fileURL.path, module: module, relativeDirectory: relativeDirectory)
    }

    // MARK: - Structs y enums

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

                    var typeName = "Any"
                    var isOptional = false
                    if let typeAnnotation = binding.typeAnnotation {
                        (typeName, isOptional) = ModelParser.splitOptional(typeAnnotation.type.trimmedDescription)
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
            properties: properties,
            module: module,
            relativeDirectory: relativeDirectory
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
            enumCases: cases,
            module: module,
            relativeDirectory: relativeDirectory
        ))

        return .skipChildren
    }

    // MARK: - Protocolos

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        var methods: [MethodRequirement] = []
        var properties: [PropertyRequirement] = []
        var unsupported: [String] = []

        for member in node.memberBlock.members {
            let decl = member.decl
            if let function = decl.as(FunctionDeclSyntax.self) {
                methods.append(ModelParser.requirement(from: function))
            } else if let variable = decl.as(VariableDeclSyntax.self) {
                properties.append(contentsOf: ModelParser.requirements(from: variable))
            } else if decl.is(AssociatedTypeDeclSyntax.self) {
                unsupported.append("associatedtype")
            } else if decl.is(InitializerDeclSyntax.self) {
                unsupported.append("init")
            } else if decl.is(SubscriptDeclSyntax.self) {
                unsupported.append("subscript")
            }
        }

        let inherited = node.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []

        protocols.append(ProtocolDefinition(
            name: node.name.text,
            filePath: filePath,
            module: module,
            relativeDirectory: relativeDirectory,
            inheritedTypes: inherited,
            methods: methods,
            properties: properties,
            unsupportedRequirements: unsupported
        ))

        return .skipChildren
    }

    private static func requirement(from function: FunctionDeclSyntax) -> MethodRequirement {
        let signature = function.signature
        let parameters = signature.parameterClause.parameters.map { parameter -> ParameterDefinition in
            let first = parameter.firstName.text
            let label: String? = first == "_" ? nil : first
            let name = parameter.secondName?.text ?? first

            var declared = parameter.type.trimmedDescription
            var usable = tupleFriendlyType(parameter.type)
            if parameter.ellipsis != nil {
                declared += "..."
                usable = "[\(usable)]"
            }
            return ParameterDefinition(
                label: label,
                name: name,
                declaredType: declared,
                typeName: usable,
                isNonEscapingClosure: isNonEscapingClosure(parameter.type)
            )
        }

        var returnType = signature.returnClause?.type.trimmedDescription
        if returnType == "Void" || returnType == "()" {
            returnType = nil
        }

        let modifiers = function.modifiers.map(\.name.text)
        let attributes = function.attributes.compactMap { $0.as(AttributeSyntax.self)?.trimmedDescription }

        return MethodRequirement(
            name: function.name.text,
            parameters: parameters,
            returnType: returnType,
            isAsync: signature.effectSpecifiers?.asyncSpecifier != nil,
            isThrows: signature.effectSpecifiers?.throwsClause != nil,
            isStatic: modifiers.contains("static") || modifiers.contains("class"),
            isGeneric: function.genericParameterClause != nil,
            attributes: attributes
        )
    }

    private static func requirements(from variable: VariableDeclSyntax) -> [PropertyRequirement] {
        let isStatic = variable.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
        return variable.bindings.compactMap { binding -> PropertyRequirement? in
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let annotation = binding.typeAnnotation else { return nil }
            let (typeName, isOptional) = splitOptional(annotation.type.trimmedDescription)

            var isSettable = false
            if case .accessors(let accessors)? = binding.accessorBlock?.accessors {
                isSettable = accessors.contains { $0.accessorSpecifier.text == "set" }
            }

            return PropertyRequirement(
                name: pattern.identifier.text,
                typeName: typeName,
                isOptional: isOptional,
                isSettable: isSettable,
                isStatic: isStatic
            )
        }
    }

    /// Quita lo que no cabe en una tupla ni en un genérico: `@escaping`, `@autoclosure`, `inout`, `borrowing`, `consuming`.
    private static func tupleFriendlyType(_ type: TypeSyntax) -> String {
        guard let attributed = type.as(AttributedTypeSyntax.self) else {
            return type.trimmedDescription
        }
        let keptAttributes = attributed.attributes
            .compactMap { $0.as(AttributeSyntax.self)?.trimmedDescription }
            .filter { $0 != "@escaping" && $0 != "@autoclosure" }
        return (keptAttributes + [attributed.baseType.trimmedDescription]).joined(separator: " ")
    }

    /// Un tipo función sin `@escaping` (o con `@autoclosure`). Los opcionales `(() -> Void)?` son escaping.
    private static func isNonEscapingClosure(_ type: TypeSyntax) -> Bool {
        if type.is(FunctionTypeSyntax.self) {
            return true
        }
        guard let attributed = type.as(AttributedTypeSyntax.self),
              attributed.baseType.is(FunctionTypeSyntax.self) else {
            return false
        }
        let attributes = attributed.attributes.compactMap { $0.as(AttributeSyntax.self)?.trimmedDescription }
        return !attributes.contains("@escaping")
    }

    /// `User?` / `Optional<User>` -> (`User`, true); cualquier otro -> (tipo, false).
    static func splitOptional(_ rawType: String) -> (String, Bool) {
        if rawType.hasSuffix("?") {
            return (String(rawType.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines), true)
        }
        if rawType.hasPrefix("Optional<") && rawType.hasSuffix(">") {
            let start = rawType.index(rawType.startIndex, offsetBy: 9)
            let end = rawType.index(before: rawType.endIndex)
            return (String(rawType[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines), true)
        }
        return (rawType, false)
    }
}
