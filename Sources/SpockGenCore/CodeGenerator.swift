//
//  CodeGenerator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Genera el código Swift de los stubs: una extensión `.stub(...)` por modelo.
public final class CodeGenerator: Sendable {
    private let defaultValueProvider: DefaultValueProvider

    public init(defaultValueProvider: DefaultValueProvider = DefaultValueProvider()) {
        self.defaultValueProvider = defaultValueProvider
    }

    /// Archivo de un solo modelo, tal como se versiona en `Generated/.../Stubs/<Tipo>+Stub.swift`.
    public func generateFile(
        for model: ModelDefinition,
        availableModels: [String: ModelDefinition],
        imports: [String] = []
    ) -> String {
        var lines: [String] = []
        lines.append("//")
        lines.append("//  \(model.name)\(OutputLayout.fileSuffix)")
        lines.append("//  Generado por spock-gen (SpockSwift 2). No editar a mano.")
        lines.append("//")
        lines.append("//  Origen: \(model.origin)")
        lines.append("//  Si el modelo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.")
        lines.append("//")
        lines.append("")
        lines.append(contentsOf: CodeGenerator.importLines(imports))
        lines.append("")
        lines.append(generateExtension(for: model, availableModels: availableModels))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Archivo único con todos los modelos (formato legado de `Stubs.generated.swift`).
    public func generate(
        models: [ModelDefinition],
        availableModels: [String: ModelDefinition],
        imports: [String] = []
    ) -> String {
        var lines: [String] = []
        lines.append("//")
        lines.append("//  Stubs.generated.swift")
        lines.append("//  SpockSwift 2 - Prebuild Generated Stubs")
        lines.append("//")
        lines.append("//  Generated automatically by spock-gen. Do not edit directly.")
        lines.append("//")
        lines.append("")
        lines.append(contentsOf: CodeGenerator.importLines(imports))
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

    static func importLines(_ imports: [String]) -> [String] {
        var lines: [String] = ["import Foundation"]
        let uniqueImports = Array(Set(imports)).sorted()
        for imp in uniqueImports where imp != "import Foundation" {
            if imp.hasPrefix("@testable import ") {
                let module = imp.replacingOccurrences(of: "@testable import ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append("#if canImport(\(module))")
                lines.append(imp)
                lines.append("#endif")
            } else {
                lines.append(imp)
            }
        }
        return lines
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
