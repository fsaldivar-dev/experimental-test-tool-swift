//
//  Models.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

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

/// Representa un modelo (struct o enum) analizado en el código fuente de producción.
public struct ModelDefinition: Sendable, Equatable {
    public let name: String
    public let filePath: String
    public let isEnum: Bool
    public let enumCases: [String]
    public let properties: [ModelProperty]

    public init(
        name: String,
        filePath: String,
        isEnum: Bool = false,
        enumCases: [String] = [],
        properties: [ModelProperty] = []
    ) {
        self.name = name
        self.filePath = filePath
        self.isEnum = isEnum
        self.enumCases = enumCases
        self.properties = properties
    }
}

/// Representa una anotación `@Stub` encontrada en un archivo de pruebas.
public struct StubDeclaration: Sendable, Equatable {
    public let typeName: String
    public let declaredInFile: String
    public let line: Int

    public init(typeName: String, declaredInFile: String, line: Int = 1) {
        self.typeName = typeName
        self.declaredInFile = declaredInFile
        self.line = line
    }
}
