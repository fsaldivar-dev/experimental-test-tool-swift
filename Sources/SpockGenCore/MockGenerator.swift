//
//  MockGenerator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Genera el mock de un protocolo: una clase con una tabla `Calls` que tiene una llamada
/// mockeada por requisito, y un cuerpo por método que delega en ella.
///
/// ```swift
/// final class UserRepositoryMock: UserRepositoryProtocol, SpockMock, @unchecked Sendable {
///     struct Calls {
///         let fetchUser = MockedThrowingCall<Int, User>()
///     }
///     let calls = Calls()
///
///     func fetchUser(id: Int) async throws -> User {
///         try calls.fetchUser.invoke(id) ?? .stub()
///     }
/// }
/// ```
public final class MockGenerator: Sendable {
    private let defaultValueProvider: DefaultValueProvider

    public init(defaultValueProvider: DefaultValueProvider = DefaultValueProvider()) {
        self.defaultValueProvider = defaultValueProvider
    }

    /// `UserRepositoryMock` para `UserRepositoryProtocol`; el sufijo `Protocol` se omite.
    public static func mockTypeName(for protocolName: String) -> String {
        var base = protocolName
        if base.hasSuffix("Protocol"), base.count > "Protocol".count {
            base.removeLast("Protocol".count)
        }
        return base + "Mock"
    }

    /// Tipos de retorno y de propiedades que un stub debe cubrir (sin opcionales ni colecciones).
    public static func referencedTypes(in definition: ProtocolDefinition) -> [String] {
        var types: [String] = []
        for method in definition.methods {
            if let returnType = method.returnType {
                types.append(ModelParser.splitOptional(returnType).0)
            }
        }
        for property in definition.properties {
            types.append(property.typeName)
        }
        return types.filter { type in
            let first = type.first
            return first?.isUppercase == true && !type.contains("[") && !type.contains("<") && !type.contains("(")
        }
    }

    public func generateFile(
        for definition: ProtocolDefinition,
        availableModels: [String: ModelDefinition],
        imports: [String] = []
    ) -> String {
        var lines: [String] = []
        lines.append("//")
        lines.append("//  \(definition.name)\(OutputLayout.mockFileSuffix)")
        lines.append("//  Generado por spock-gen (SpockSwift 2). No editar a mano.")
        lines.append("//")
        lines.append("//  Origen: \(definition.origin)")
        lines.append("//  Si el protocolo cambia, regenera con `spock-gen`; `spock-gen check` detecta el desfase.")
        lines.append("//")
        lines.append("")
        lines.append("import Foundation")
        lines.append("import SpockSwift")
        lines.append(contentsOf: CodeGenerator.importLines(imports).dropFirst())
        lines.append("")
        lines.append(generateClass(for: definition, availableModels: availableModels))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Clase

    private struct MethodPlan {
        let method: MethodRequirement
        let callName: String
    }

    private func generateClass(for definition: ProtocolDefinition, availableModels: [String: ModelDefinition]) -> String {
        let mockName = MockGenerator.mockTypeName(for: definition.name)
        let callNames = uniqueCallNames(for: definition.methods)
        let plans = zip(definition.methods, callNames).map { MethodPlan(method: $0, callName: $1) }
        let instanceCalls = plans.filter { !$0.method.isStatic && !$0.method.isGeneric }
        let staticCalls = plans.filter { $0.method.isStatic && !$0.method.isGeneric }

        var lines: [String] = []
        lines.append("final class \(mockName): \(definition.name), SpockMock, @unchecked Sendable {")
        lines.append("")
        lines.append("    struct Calls {")
        for plan in instanceCalls {
            lines.append("        let \(plan.callName) = \(callType(for: plan.method))()")
        }
        lines.append("    }")
        lines.append("    let calls = Calls()")

        if !staticCalls.isEmpty {
            lines.append("")
            lines.append("    struct StaticCalls {")
            for plan in staticCalls {
                lines.append("        let \(plan.callName) = \(callType(for: plan.method))()")
            }
            lines.append("    }")
            lines.append("    static let staticCalls = StaticCalls()")
        }

        for property in definition.properties {
            lines.append("")
            lines.append(generateProperty(property, availableModels: availableModels))
        }

        for plan in plans {
            lines.append("")
            lines.append(contentsOf: generateMethod(plan, mockName: mockName, availableModels: availableModels))
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func callType(for method: MethodRequirement) -> String {
        let input = tupleType(for: method.parameters)
        let output = method.returnType.map { ModelParser.splitOptional($0).0 } ?? "Void"
        let name = method.isThrows ? "MockedThrowingCall" : "MockedCall"
        return "\(name)<\(input), \(output)>"
    }

    private func generateProperty(_ property: PropertyRequirement, availableModels: [String: ModelDefinition]) -> String {
        let modelProperty = ModelProperty(name: property.name, typeName: property.typeName, isOptional: property.isOptional)
        let defaultValue = defaultValueProvider.defaultValue(for: modelProperty, availableModels: availableModels)
        let type = property.isOptional ? "\(property.typeName)?" : property.typeName
        let prefix = property.isStatic ? "static var" : "var"
        return "    \(prefix) \(property.name): \(type) = \(defaultValue)"
    }

    private func generateMethod(_ plan: MethodPlan, mockName: String, availableModels: [String: ModelDefinition]) -> [String] {
        let method = plan.method
        var lines: [String] = []
        let signature = signatureText(for: method)

        if method.isGeneric {
            lines.append("    // Requisito genérico: no se puede registrar en una llamada mockeada con tipos fijos.")
            lines.append("    \(signature) {")
            lines.append("        fatalError(\"\\(Self.self).\(method.selector) es genérico y no está mockeado\")")
            lines.append("    }")
            return lines
        }

        lines.append("    \(signature) {")
        lines.append("        \(body(for: plan, mockName: mockName, availableModels: availableModels))")
        lines.append("    }")
        return lines
    }

    private func body(for plan: MethodPlan, mockName: String, availableModels: [String: ModelDefinition]) -> String {
        let method = plan.method
        let callReference = method.isStatic ? "\(mockName).staticCalls.\(plan.callName)" : "calls.\(plan.callName)"
        let nonEscaping = method.parameters.filter(\.isNonEscapingClosure)
        let recording = nonEscaping.isEmpty ? "" : ", recording: false"
        let invoke = "\(callReference).invoke(\(callArgumentsText(for: method.parameters))\(recording))"
        let tryPrefix = method.isThrows ? "try " : ""

        var expression: String
        if let returnType = method.returnType {
            let (outputType, isOptional) = ModelParser.splitOptional(returnType)
            if isOptional {
                expression = "\(tryPrefix)\(invoke)"
            } else {
                let fallback = defaultValueProvider.defaultValue(
                    for: ModelProperty(name: method.name, typeName: outputType, isOptional: false),
                    availableModels: availableModels
                )
                expression = "\(tryPrefix)\(invoke) ?? \(fallback)"
            }
        } else {
            expression = "\(tryPrefix)\(invoke)"
        }

        // Los closures no escaping no se pueden guardar: se prestan durante la invocación.
        for parameter in nonEscaping.reversed() {
            expression = "\(tryPrefix)withoutActuallyEscaping(\(parameter.name)) { \(parameter.name) in \(expression) }"
        }

        if method.returnType == nil {
            return "_ = \(expression)"
        }
        return expression
    }

    // MARK: - Texto

    private func signatureText(for method: MethodRequirement) -> String {
        var parts: [String] = []
        parts.append(contentsOf: method.attributes)
        if method.isStatic { parts.append("static") }
        var declaration = "func \(method.name)(\(method.parameters.map(\.signatureText).joined(separator: ", ")))"
        if method.isAsync { declaration += " async" }
        if method.isThrows { declaration += " throws" }
        if let returnType = method.returnType { declaration += " -> \(returnType)" }
        parts.append(declaration)
        return parts.joined(separator: " ")
    }

    /// `()`, `Int` o `(id: Int, name: String)` según la cantidad de parámetros.
    private func tupleType(for parameters: [ParameterDefinition]) -> String {
        switch parameters.count {
        case 0: return "()"
        case 1: return parameters[0].typeName
        default: return "(" + parameters.map { "\($0.name): \($0.typeName)" }.joined(separator: ", ") + ")"
        }
    }

    private func callArgumentsText(for parameters: [ParameterDefinition]) -> String {
        switch parameters.count {
        case 0: return "()"
        case 1: return parameters[0].name
        default: return "(" + parameters.map { "\($0.name): \($0.name)" }.joined(separator: ", ") + ")"
        }
    }

    /// `fetchUser`; ante sobrecargas, `fetchUserId` / `fetchUserName`.
    private func uniqueCallNames(for methods: [MethodRequirement]) -> [String] {
        var counts: [String: Int] = [:]
        for method in methods { counts[method.name, default: 0] += 1 }

        var names: [String] = []
        for method in methods {
            if counts[method.name] == 1 {
                names.append(method.name)
            } else {
                let labels = method.parameters.map { ($0.label ?? $0.name).capitalizedFirst }.joined()
                names.append("\(method.name)\(labels)")
            }
        }

        // Si aun así se repiten, numerarlos.
        var seen: [String: Int] = [:]
        return names.map { name in
            seen[name, default: 0] += 1
            return seen[name] == 1 ? name : name + String(seen[name]!)
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
