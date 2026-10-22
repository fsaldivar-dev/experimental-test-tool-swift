//
//  Models.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Raíz de fuentes de un módulo: el nombre del módulo y el directorio donde viven sus archivos.
///
/// Los stubs generados reflejan la ruta del archivo de origen relativa a esta raíz:
/// `Generated/<module>/<ruta relativa>/Stubs/<Tipo>+Stub.swift`.
public struct SourceRoot: Sendable, Equatable, Hashable {
    public let module: String
    public let path: String

    public init(module: String, path: String) {
        self.module = module
        self.path = SourceRoot.normalize(path)
    }

    /// Acepta `Módulo=ruta` o solo `ruta`; en el segundo caso el módulo se infiere del último componente.
    public static func parse(_ spec: String) -> SourceRoot {
        if let separator = spec.firstIndex(of: "="), separator != spec.startIndex {
            let module = String(spec[..<separator]).trimmingCharacters(in: .whitespaces)
            let path = String(spec[spec.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if !module.isEmpty, !path.isEmpty {
                return SourceRoot(module: module, path: path)
            }
        }
        return SourceRoot(module: inferredModuleName(for: spec), path: spec)
    }

    /// Nombre de módulo inferido de una ruta: su último componente.
    public static func inferredModuleName(for path: String) -> String {
        let name = (normalize(path) as NSString).lastPathComponent
        return name.isEmpty || name == "." ? "Module" : name
    }

    /// `Módulo=ruta`, la forma que acepta la CLI.
    public var spec: String { "\(module)=\(path)" }

    /// Directorio del archivo relativo a esta raíz: `""` si está en la raíz, `nil` si no pertenece a ella.
    public func relativeDirectory(of filePath: String) -> String? {
        let file = SourceRoot.normalize(filePath)
        let prefix = path + "/"
        guard file.hasPrefix(prefix) else { return nil }
        let relative = String(file.dropFirst(prefix.count))
        return (relative as NSString).deletingLastPathComponent
    }

    static func normalize(_ path: String) -> String {
        var result = path
        while result.hasPrefix("./") { result.removeFirst(2) }
        while result.count > 1, result.hasSuffix("/") { result.removeLast() }
        return result
    }
}

/// Representa una propiedad individual de un modelo analizado.
public struct ModelProperty: Sendable, Equatable {
    public let name: String
    public let typeName: String
    public let isOptional: Bool
    public let defaultValue: String?

    public init(name: String, typeName: String, isOptional: Bool = false, defaultValue: String? = nil) {
        self.name = name
        self.typeName = typeName
        self.isOptional = isOptional
        self.defaultValue = defaultValue
    }
}

/// Representa un modelo (struct o enum) analizado en el código fuente.
public struct ModelDefinition: Sendable, Equatable {
    public let name: String
    public let filePath: String
    public let isEnum: Bool
    public let enumCases: [String]
    public let properties: [ModelProperty]
    /// Módulo al que pertenece el archivo de origen.
    public let module: String
    /// Directorio del archivo de origen relativo a la raíz de su módulo (`""` si está en la raíz).
    public let relativeDirectory: String

    public init(
        name: String,
        filePath: String,
        isEnum: Bool = false,
        enumCases: [String] = [],
        properties: [ModelProperty] = [],
        module: String = "",
        relativeDirectory: String = ""
    ) {
        self.name = name
        self.filePath = filePath
        self.isEnum = isEnum
        self.enumCases = enumCases
        self.properties = properties
        self.module = module
        self.relativeDirectory = relativeDirectory
    }

    /// Origen portable del modelo: `<module>/<ruta relativa>/<archivo>`.
    public var origin: String {
        let file = (filePath as NSString).lastPathComponent
        let parts = [module, relativeDirectory, file].filter { !$0.isEmpty }
        return parts.joined(separator: "/")
    }
}

/// Qué pide una anotación encontrada en tests.
public enum DeclarationKind: String, Sendable, Equatable {
    /// `@Stubbed extension Tipo {}` o un modelo usado con `.stub()`: genera `Tipo.stub(...)`.
    case stub
    /// `@Mocking extension Protocolo {}`: genera `MockProtocolo` con un llamada mockeada por requisito.
    case mock
}

/// Representa una anotación `@Stubbed` / `@Mocking` encontrada en un archivo de pruebas.
public struct StubDeclaration: Sendable, Equatable {
    public let typeName: String
    public let declaredInFile: String
    public let line: Int
    /// `true` para una anotación escrita; `false` cuando el modelo se descubrió por su uso en un test.
    public let isExplicit: Bool
    public let kind: DeclarationKind

    public init(
        typeName: String,
        declaredInFile: String,
        line: Int = 1,
        isExplicit: Bool = true,
        kind: DeclarationKind = .stub
    ) {
        self.typeName = typeName
        self.declaredInFile = declaredInFile
        self.line = line
        self.isExplicit = isExplicit
        self.kind = kind
    }
}

// MARK: - Protocolos

/// Parámetro de un requisito de protocolo.
public struct ParameterDefinition: Sendable, Equatable {
    /// Etiqueta externa; `nil` cuando se declaró `_`.
    public let label: String?
    /// Nombre interno, el que se usa dentro del cuerpo.
    public let name: String
    /// Tipo tal como se declaró (`@escaping () -> Void`, `inout Int`, `Int...`).
    public let declaredType: String
    /// Tipo utilizable dentro de una tupla o genérico (`() -> Void`, `Int`, `[Int]`).
    public let typeName: String
    /// Closure sin `@escaping` (o `@autoclosure`): no se puede guardar, el mock lo pasa con `withoutActuallyEscaping`.
    public let isNonEscapingClosure: Bool

    public init(label: String?, name: String, declaredType: String, typeName: String? = nil, isNonEscapingClosure: Bool = false) {
        self.label = label
        self.name = name
        self.declaredType = declaredType
        self.typeName = typeName ?? declaredType
        self.isNonEscapingClosure = isNonEscapingClosure
    }

    /// `label name: Tipo` tal como va en la firma.
    public var signatureText: String {
        let prefix: String
        if let label {
            prefix = label == name ? name : "\(label) \(name)"
        } else {
            prefix = "_ \(name)"
        }
        return "\(prefix): \(declaredType)"
    }
}

/// Método requerido por un protocolo.
public struct MethodRequirement: Sendable, Equatable {
    public let name: String
    public let parameters: [ParameterDefinition]
    /// `nil` cuando devuelve `Void`.
    public let returnType: String?
    public let isAsync: Bool
    public let isThrows: Bool
    public let isStatic: Bool
    public let isGeneric: Bool
    /// Atributos a replicar en la implementación (`@MainActor`, `@discardableResult`).
    public let attributes: [String]

    public init(
        name: String,
        parameters: [ParameterDefinition] = [],
        returnType: String? = nil,
        isAsync: Bool = false,
        isThrows: Bool = false,
        isStatic: Bool = false,
        isGeneric: Bool = false,
        attributes: [String] = []
    ) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrows = isThrows
        self.isStatic = isStatic
        self.isGeneric = isGeneric
        self.attributes = attributes
    }

    /// `fetchUser(id:)`, útil para nombres únicos y mensajes.
    public var selector: String {
        "\(name)(\(parameters.map { ($0.label ?? "_") + ":" }.joined()))"
    }
}

/// Propiedad requerida por un protocolo.
public struct PropertyRequirement: Sendable, Equatable {
    public let name: String
    public let typeName: String
    public let isOptional: Bool
    public let isSettable: Bool
    public let isStatic: Bool

    public init(name: String, typeName: String, isOptional: Bool = false, isSettable: Bool = false, isStatic: Bool = false) {
        self.name = name
        self.typeName = typeName
        self.isOptional = isOptional
        self.isSettable = isSettable
        self.isStatic = isStatic
    }
}

/// Representa un protocolo analizado en el código fuente.
public struct ProtocolDefinition: Sendable, Equatable {
    public let name: String
    public let filePath: String
    public let module: String
    public let relativeDirectory: String
    /// Protocolos de los que hereda (`Sendable`, `AnyObject`, otros del dominio).
    public let inheritedTypes: [String]
    public let methods: [MethodRequirement]
    public let properties: [PropertyRequirement]
    /// Requisitos que el mock no puede satisfacer: `associatedtype`, `init`, `subscript`.
    public let unsupportedRequirements: [String]

    public init(
        name: String,
        filePath: String = "",
        module: String = "",
        relativeDirectory: String = "",
        inheritedTypes: [String] = [],
        methods: [MethodRequirement] = [],
        properties: [PropertyRequirement] = [],
        unsupportedRequirements: [String] = []
    ) {
        self.name = name
        self.filePath = filePath
        self.module = module
        self.relativeDirectory = relativeDirectory
        self.inheritedTypes = inheritedTypes
        self.methods = methods
        self.properties = properties
        self.unsupportedRequirements = unsupportedRequirements
    }

    /// Origen portable: `<module>/<ruta relativa>/<archivo>`.
    public var origin: String {
        let file = (filePath as NSString).lastPathComponent
        return [module, relativeDirectory, file].filter { !$0.isEmpty }.joined(separator: "/")
    }

    /// Copia con los requisitos de los protocolos padre añadidos (sin repetir).
    public func merging(parents: [ProtocolDefinition]) -> ProtocolDefinition {
        var methods = self.methods
        var properties = self.properties
        var unsupported = self.unsupportedRequirements
        for parent in parents {
            for method in parent.methods where !methods.contains(where: { $0.selector == method.selector && $0.isStatic == method.isStatic }) {
                methods.append(method)
            }
            for property in parent.properties where !properties.contains(where: { $0.name == property.name && $0.isStatic == property.isStatic }) {
                properties.append(property)
            }
            unsupported.append(contentsOf: parent.unsupportedRequirements)
        }
        return ProtocolDefinition(
            name: name,
            filePath: filePath,
            module: module,
            relativeDirectory: relativeDirectory,
            inheritedTypes: inheritedTypes,
            methods: methods,
            properties: properties,
            unsupportedRequirements: unsupported
        )
    }
}
