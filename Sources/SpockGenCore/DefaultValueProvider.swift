//
//  DefaultValueProvider.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Sintetiza valores por defecto inteligentes y seguros para los parámetros de `.stub(...)`.
public final class DefaultValueProvider: Sendable {
    public init() {}

    public func defaultValue(
        for property: ModelProperty,
        availableModels: [String: ModelDefinition]
    ) -> String {
        // 1. Si la propiedad ya tiene un valor por defecto explícito en el modelo, respetarlo
        if let explicit = property.defaultValue {
            return explicit
        }

        // 2. Si es opcional, el valor por defecto siempre es nil
        if property.isOptional {
            return "nil"
        }

        let type = property.typeName

        // 3. Tipos primitivos estándar de Swift
        switch type {
        case "String":
            return "\"dummy_\(property.name)\""
        case "Int", "Int64", "Int32", "Int16", "Int8":
            return property.name.lowercased().contains("id") ? "1" : "0"
        case "UInt", "UInt64", "UInt32", "UInt16", "UInt8":
            return property.name.lowercased().contains("id") ? "1" : "0"
        case "Double":
            return "0.0"
        case "Float":
            return "0.0"
        case "Bool":
            return "false"
        case "UUID":
            return "UUID()"
        case "Date":
            return "Date()"
        case "URL":
            return "URL(string: \"https://example.com\")!"
        case "Data":
            return "Data()"
        default:
            break
        }

        // 4. Colecciones estándar
        if type.hasPrefix("[") && type.hasSuffix("]") {
            return "[]"
        }
        if type.hasPrefix("Array<") || type.hasPrefix("Set<") {
            return "[]"
        }
        if type.hasPrefix("Dictionary<") {
            return "[:]"
        }

        // 5. Enums: usa el primer caso válido (elimina crashes de v1)
        if let model = availableModels[type], model.isEnum, let firstCase = model.enumCases.first {
            return ".\(firstCase)"
        }

        // 6. Modelos hijos personalizados en autoTree: encadena con .stub()
        if availableModels[type] != nil {
            return ".stub()"
        }

        // 7. Fallback seguro
        return ".stub()"
    }
}
