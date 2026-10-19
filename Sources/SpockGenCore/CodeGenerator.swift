//
//  CodeGenerator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Genera el archivo final `Stubs.generated.swift` con la sintaxis limpia `.stub(...)` en extensiones de los modelos.
public final class CodeGenerator: Sendable {
    private let defaultValueProvider: DefaultValueProvider

    public init(defaultValueProvider: DefaultValueProvider = DefaultValueProvider()) {
        self.defaultValueProvider = defaultValueProvider
    }

    public func generate(
        models: [ModelDefinition],
        availableModels: [String: ModelDefinition]
    ) -> String {
        var lines: [String] = []
        lines.append("//")
        lines.append("//  Stubs.generated.swift")
        lines.append("//  SpockSwift 2 - Prebuild Generated Stubs")
        lines.append("//")
        lines.append("//  Generated automatically by spock-gen. Do not edit directly.")
        lines.append("//")
        lines.append("")
        lines.append("import Foundation")
        lines.append("")

        for model in models {
            // Los enums no requieren extensión .stub(), sus casos se usan directamente
            if model.isEnum { continue }

            let extensionCode = generateExtension(for: model, availableModels: availableModels)
            lines.append(extensionCode)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func generateExtension(
        for model: ModelDefinition,
        availableModels: [String: ModelDefinition]
    ) -> String {
        let name = model.name
        var lines: [String] = []
        lines.append("extension \(name) {")

        if model.properties.isEmpty {
            lines.append("    public static func stub() -> \(name) {")
            lines.append("        \(name)()")
            lines.append("    }")
        } else {
            var params: [String] = []
            var callArgs: [String] = []

            for prop in model.properties {
                let defaultVal = defaultValueProvider.defaultValue(for: prop, availableModels: availableModels)
                let typeSignature = prop.isOptional ? "\(prop.typeName)?" : prop.typeName
                params.append("        \(prop.name): \(typeSignature) = \(defaultVal)")
                callArgs.append("            \(prop.name): \(prop.name)")
            }

            lines.append("    public static func stub(")
            lines.append(params.joined(separator: ",\n"))
            lines.append("    ) -> \(name) {")
            lines.append("        \(name)(")
            lines.append(callArgs.joined(separator: ",\n"))
            lines.append("        )")
            lines.append("    }")
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }
}
