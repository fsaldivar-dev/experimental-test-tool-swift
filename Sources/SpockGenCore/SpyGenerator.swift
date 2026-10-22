//
//  SpyGenerator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Genera el espía de una implementación real: un envoltorio que conforma a los mismos protocolos,
/// guarda la implementación, registra cada llamada y siempre delega en ella. Solo espía, no mockea.
///
/// ```swift
/// final class InMemoryUserRepositorySpy: UserRepositoryProtocol, SpockMock, @unchecked Sendable {
///     struct Calls {
///         let fetchUser = SpiedCall<Int>()
///     }
///     let calls = Calls()
///     var inMemoryUserRepository: InMemoryUserRepository
///
///     init(_ inMemoryUserRepository: InMemoryUserRepository) { … }
///
///     func fetchUser(id: Int) async throws -> User {
///         calls.fetchUser.record(id)
///         return try await inMemoryUserRepository.fetchUser(id: id)
///     }
/// }
/// ```
public final class SpyGenerator: Sendable {

    public init() {}

    /// `InMemoryUserRepositorySpy` para `InMemoryUserRepository`.
    public static func spyTypeName(for typeName: String) -> String {
        typeName + "Spy"
    }

    /// `inMemoryUserRepository` para `InMemoryUserRepository`; `urlSession` para `URLSession`.
    public static func wrappedPropertyName(for typeName: String) -> String {
        let characters = Array(typeName)
        guard let first = characters.first, first.isUppercase else { return typeName }
        var prefixLength = characters.prefix { $0.isUppercase }.count
        if prefixLength > 1, prefixLength < characters.count {
            prefixLength -= 1   // `URLSession` -> `url` + `Session`
        }
        let lowered = String(characters[..<prefixLength]).lowercased()
        return lowered + String(characters[prefixLength...])
    }

    /// Qué métodos y propiedades reenvía el espía: los requisitos de los protocolos conocidos del tipo,
    /// o todos sus métodos no privados si no conforma a ninguno conocido.
    public struct Surface: Sendable, Equatable {
        public let protocols: [String]
        public let methods: [MethodRequirement]
        public let properties: [PropertyRequirement]

        public init(protocols: [String], methods: [MethodRequirement], properties: [PropertyRequirement]) {
            self.protocols = protocols
            self.methods = methods
            self.properties = properties
        }
    }

    public static func surface(of implementation: ImplementationDefinition, conforming protocols: [ProtocolDefinition]) -> Surface {
        guard !protocols.isEmpty else {
            return Surface(protocols: [], methods: implementation.methods, properties: [])
        }
        var methods: [MethodRequirement] = []
        var properties: [PropertyRequirement] = []
        for definition in protocols {
            for method in definition.methods where !methods.contains(where: { $0.selector == method.selector && $0.isStatic == method.isStatic }) {
                methods.append(method)
            }
            for property in definition.properties where !properties.contains(where: { $0.name == property.name && $0.isStatic == property.isStatic }) {
                properties.append(property)
            }
        }
        return Surface(protocols: protocols.map(\.name), methods: methods, properties: properties)
    }

    public func generateFile(
        for implementation: ImplementationDefinition,
        conforming protocols: [ProtocolDefinition],
        imports: [String] = []
    ) -> String {
        var lines: [String] = []
        lines.append("//")
        lines.append("//  \(implementation.name)\(OutputLayout.spyFileSuffix)")
        lines.append("//  Generado por spock-gen (SpockSwift 2). No editar a mano.")
        lines.append("//")
        lines.append("//  Origen: \(implementation.origin)")
        lines.append("//  Si el tipo o sus protocolos cambian, regenera con `spock-gen`; `spock-gen check` detecta el desfase.")
        lines.append("//")
        lines.append("")
        lines.append("import Foundation")
        lines.append("import SpockSwift")
        lines.append(contentsOf: CodeGenerator.importLines(imports).dropFirst())
        lines.append("")
        lines.append(generateClass(for: implementation, surface: SpyGenerator.surface(of: implementation, conforming: protocols)))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Clase

    private func generateClass(for implementation: ImplementationDefinition, surface: Surface) -> String {
        let spyName = SpyGenerator.spyTypeName(for: implementation.name)
        let wrapped = SpyGenerator.wrappedPropertyName(for: implementation.name)
        let supported = surface.methods.filter { !$0.isGeneric && !$0.parameters.contains(where: \.isVariadic) }
        let callNames = uniqueCallNames(for: supported)
        let plans = zip(supported, callNames).map { (method: $0, callName: $1) }
        let instance = plans.filter { !$0.method.isStatic }
        let statics = plans.filter { $0.method.isStatic }
        let conformances = surface.protocols + ["SpockMock", "@unchecked Sendable"]

        var lines: [String] = []
        lines.append("/// Espía de `\(implementation.name)`: registra cada llamada y delega en la implementación real.")
        lines.append("final class \(spyName): \(conformances.joined(separator: ", ")) {")
        lines.append("")
        lines.append("    struct Calls {")
        for plan in instance {
            lines.append("        let \(plan.callName) = SpiedCall<\(tupleType(for: plan.method.parameters))>()")
        }
        lines.append("    }")
        lines.append("    let calls = Calls()")
        if !statics.isEmpty {
            lines.append("")
            lines.append("    struct StaticCalls {")
            for plan in statics {
                lines.append("        let \(plan.callName) = SpiedCall<\(tupleType(for: plan.method.parameters))>()")
            }
            lines.append("    }")
            lines.append("    static let staticCalls = StaticCalls()")
        }
        lines.append("")
        lines.append("    var \(wrapped): \(implementation.name)")
        lines.append("")
        lines.append("    init(_ \(wrapped): \(implementation.name)) {")
        lines.append("        self.\(wrapped) = \(wrapped)")
        lines.append("    }")

        for property in surface.properties {
            lines.append("")
            lines.append(contentsOf: generateProperty(property, wrapped: wrapped, typeName: implementation.name))
        }

        for plan in plans {
            lines.append("")
            lines.append(contentsOf: generateMethod(plan.method, callName: plan.callName, wrapped: wrapped, typeName: implementation.name))
        }

        let skipped = surface.methods.filter { $0.isGeneric || $0.parameters.contains(where: \.isVariadic) }
        for method in skipped {
            lines.append("")
            lines.append("    // \(method.selector) no se espía: " + (method.isGeneric ? "es genérico." : "tiene parámetros variádicos, que no se pueden reenviar."))
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func generateProperty(_ property: PropertyRequirement, wrapped: String, typeName: String) -> [String] {
        let type = property.isOptional ? "\(property.typeName)?" : property.typeName
        let target = property.isStatic ? typeName : wrapped
        let prefix = property.isStatic ? "static var" : "var"
        if property.isSettable {
            return [
                "    \(prefix) \(property.name): \(type) {",
                "        get { \(target).\(property.name) }",
                "        set { \(target).\(property.name) = newValue }",
                "    }"
            ]
        }
        return ["    \(prefix) \(property.name): \(type) { \(target).\(property.name) }"]
    }

    private func generateMethod(_ method: MethodRequirement, callName: String, wrapped: String, typeName: String) -> [String] {
        let callReference = method.isStatic ? "Self.staticCalls.\(callName)" : "calls.\(callName)"
        let target = method.isStatic ? typeName : wrapped
        var effects = ""
        if method.isThrows { effects += "try " }
        if method.isAsync { effects += "await " }
        let forward = "\(effects)\(target).\(method.name)(\(method.parameters.map(\.forwardingText).joined(separator: ", ")))"

        var lines: [String] = []
        lines.append("    \(signatureText(for: method)) {")
        lines.append("        \(callReference).record(\(recordArguments(for: method.parameters)))")
        lines.append(method.returnType == nil ? "        \(forward)" : "        return \(forward)")
        lines.append("    }")
        return lines
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

    /// Tipo registrado por parámetro: los closures no escaping no se pueden guardar y quedan como `Void`.
    private func recordedType(of parameter: ParameterDefinition) -> String {
        parameter.isNonEscapingClosure ? "Void" : parameter.typeName
    }

    private func recordedValue(of parameter: ParameterDefinition) -> String {
        parameter.isNonEscapingClosure ? "()" : parameter.name
    }

    /// `()`, `Int` o `(id: Int, note: String?)`.
    private func tupleType(for parameters: [ParameterDefinition]) -> String {
        switch parameters.count {
        case 0: return "()"
        case 1: return recordedType(of: parameters[0])
        default: return "(" + parameters.map { "\($0.name): \(recordedType(of: $0))" }.joined(separator: ", ") + ")"
        }
    }

    private func recordArguments(for parameters: [ParameterDefinition]) -> String {
        switch parameters.count {
        case 0: return "()"
        case 1: return recordedValue(of: parameters[0])
        default: return "(" + parameters.map { "\($0.name): \(recordedValue(of: $0))" }.joined(separator: ", ") + ")"
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
                let labels = method.parameters.map { parameter -> String in
                    let label = parameter.label ?? parameter.name
                    return label.prefix(1).uppercased() + label.dropFirst()
                }.joined()
                names.append("\(method.name)\(labels)")
            }
        }

        var seen: [String: Int] = [:]
        return names.map { name in
            seen[name, default: 0] += 1
            return seen[name] == 1 ? name : name + String(seen[name]!)
        }
    }
}
