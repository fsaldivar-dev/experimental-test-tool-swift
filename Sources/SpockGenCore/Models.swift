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

/// Representa una anotación `@Stubbed` encontrada en un archivo de pruebas.
public struct StubDeclaration: Sendable, Equatable {
    public let typeName: String
    public let declaredInFile: String
    public let line: Int
    /// `true` para `@Stubbed`; `false` cuando el modelo se descubrió por su uso en un test.
    public let isExplicit: Bool

    public init(typeName: String, declaredInFile: String, line: Int = 1, isExplicit: Bool = true) {
        self.typeName = typeName
        self.declaredInFile = declaredInFile
        self.line = line
        self.isExplicit = isExplicit
    }
}
