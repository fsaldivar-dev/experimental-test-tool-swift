//
//  DefaultValueProvider.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Sintetiza valores por defecto para los parámetros de `.stub(...)` y los fallbacks de los mocks.
///
/// Dos estilos, ambos deterministas:
/// - `.realistic` (por defecto): valores con sentido según el nombre y el tipo de la propiedad
///   (`name` → `"Ana García"`, `email` → `"ana.garcia@example.com"`, `createdAt` → una fecha fija).
/// - `.plain`: el valor plano de siempre (`"dummy_name"`, `0`, `Date()`).
public final class DefaultValueProvider: Sendable {
    public enum Style: String, Sendable, Equatable, CaseIterable {
        case plain
        case realistic
    }

    public let style: Style

    public init(style: Style = .realistic) {
        self.style = style
    }

    /// Fecha fija para que los stubs no cambien entre corridas: 2023-11-14 22:13:20 UTC.
    public static let fixedDate = "Date(timeIntervalSince1970: 1_700_000_000)"
    /// UUID fijo y legible.
    public static let fixedUUID = "UUID(uuidString: \"00000000-0000-0000-0000-000000000001\")!"

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
        let tokens = DefaultValueProvider.tokens(of: property.name)

        // 3. Tipos primitivos estándar de Swift
        switch type {
        case "String":
            return "\"\(stringValue(tokens: tokens, name: property.name))\""
        case "Int", "Int64", "Int32", "Int16", "Int8", "UInt", "UInt64", "UInt32", "UInt16", "UInt8":
            return String(integerValue(tokens: tokens))
        case "Double", "Float", "CGFloat":
            return doubleValue(tokens: tokens)
        case "Decimal":
            return style == .realistic && DefaultValueProvider.isAmount(tokens) ? "9.99" : "0"
        case "Bool":
            return boolValue(tokens: tokens) ? "true" : "false"
        case "UUID":
            return style == .realistic ? DefaultValueProvider.fixedUUID : "UUID()"
        case "Date":
            return style == .realistic ? DefaultValueProvider.fixedDate : "Date()"
        case "URL":
            return "URL(string: \"\(urlValue(tokens: tokens))\")!"
        case "Data":
            return "Data()"
        default:
            break
        }

        // 4. Colecciones estándar
        if type.hasPrefix("[") && type.hasSuffix("]") {
            return type.contains(":") ? "[:]" : "[]"
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
        return ".stub()"
    }

    /// Expresión que varía con `index` (1-based) para `stubs(count:)`, o `nil` si la propiedad no cambia entre instancias.
    public func variedValue(
        for property: ModelProperty,
        availableModels: [String: ModelDefinition]
    ) -> String? {
        guard property.defaultValue == nil, !property.isOptional else { return nil }
        let tokens = DefaultValueProvider.tokens(of: property.name)

        switch property.typeName {
        case "Int", "Int64", "Int32", "Int16", "Int8", "UInt", "UInt64", "UInt32", "UInt16", "UInt8":
            return DefaultValueProvider.isIdentifier(tokens) ? "index" : nil
        case "UUID":
            return "UUID(uuidString: String(format: \"00000000-0000-0000-0000-%012d\", index))!"
        case "String":
            let base = stringValue(tokens: tokens, name: property.name)
            if tokens.contains("email") || tokens.contains("mail") {
                let parts = base.split(separator: "@", maxSplits: 1).map(String.init)
                return parts.count == 2 ? "\"\(parts[0])\\(index)@\(parts[1])\"" : "\"\(base)\\(index)\""
            }
            return base.hasPrefix("dummy_") ? "\"\(base)_\\(index)\"" : "\"\(base) \\(index)\""
        default:
            return nil
        }
    }

    // MARK: - Reglas

    /// `avatarURL` → `["avatar", "url"]`; `userId` → `["user", "id"]`.
    static func tokens(of name: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        let characters = Array(name)
        for (i, character) in characters.enumerated() {
            if character == "_" {
                if !current.isEmpty { tokens.append(current.lowercased()); current = "" }
                continue
            }
            if character.isUppercase, !current.isEmpty {
                let previous = characters[i - 1]
                let next = i + 1 < characters.count ? characters[i + 1] : nil
                // Corte en minúscula→Mayúscula, o al final de una sigla (URLPath → url, path)
                if previous.isLowercase || previous.isNumber || (next.map { $0.isLowercase } ?? false) {
                    tokens.append(current.lowercased()); current = ""
                }
            }
            current.append(character)
        }
        if !current.isEmpty { tokens.append(current.lowercased()) }
        return tokens
    }

    static func isIdentifier(_ tokens: [String]) -> Bool {
        tokens.last == "id" || tokens.last == "identifier" || tokens == ["uid"]
    }

    static func isAmount(_ tokens: [String]) -> Bool {
        !Set(tokens).isDisjoint(with: ["price", "amount", "cost", "total", "balance", "salary", "fee", "subtotal", "tax"])
    }

    private func stringValue(tokens: [String], name: String) -> String {
        guard style == .realistic else { return "dummy_\(name)" }
        let set = Set(tokens)
        func has(_ words: String...) -> Bool { !set.isDisjoint(with: words) }

        if has("email", "mail") { return "ana.garcia@example.com" }
        if has("username", "handle", "nickname", "nick", "alias") { return "ana.garcia" }
        if set.contains("name") && has("first", "given") { return "Ana" }
        if set.contains("name") && has("last", "family") || has("surname", "lastname") { return "García" }
        if has("name", "fullname", "displayname", "author", "owner") { return "Ana García" }
        if has("title", "subject", "headline", "label") { return "Título de ejemplo" }
        if has("description", "bio", "summary", "notes", "note", "message", "text", "body", "content", "comment", "caption") { return "Texto de ejemplo" }
        if has("phone", "mobile", "tel", "telephone", "cellphone") { return "+52 55 1234 5678" }
        if has("image", "avatar", "photo", "thumbnail", "picture", "icon", "logo") { return "https://example.com/image.png" }
        if has("url", "link", "website", "href", "uri") { return "https://example.com" }
        if has("address", "street") { return "Av. Reforma 123" }
        if has("city", "town") { return "Ciudad de México" }
        if has("country") { return "México" }
        if has("zip", "zipcode", "postal", "postcode") || tokens == ["cp"] { return "06600" }
        if has("currency") { return "MXN" }
        if has("password", "token", "secret", "apikey", "key") { return "secret" }
        if has("code", "sku", "reference", "ref") { return "ABC123" }
        if has("version") { return "1.0.0" }
        if has("language", "locale", "lang") { return "es-MX" }
        if has("color", "colour") { return "#FF5733" }
        if has("status", "state") { return "active" }
        if DefaultValueProvider.isIdentifier(tokens) { return "id-1" }
        return "dummy_\(name)"
    }

    private func integerValue(tokens: [String]) -> Int {
        if DefaultValueProvider.isIdentifier(tokens) { return 1 }
        guard style == .realistic else { return 0 }
        let set = Set(tokens)
        func has(_ words: String...) -> Bool { !set.isDisjoint(with: words) }
        if has("age") { return 30 }
        if has("year") { return 2024 }
        if has("month", "day", "page", "level", "rank", "position", "index") { return 1 }
        if has("count", "quantity", "qty", "total", "size", "length", "number", "items", "stock", "retries", "attempts", "limit", "max") { return 3 }
        if DefaultValueProvider.isAmount(tokens) { return 100 }
        if has("percent", "percentage", "progress") { return 50 }
        if has("width", "height") { return 100 }
        return 0
    }

    private func doubleValue(tokens: [String]) -> String {
        guard style == .realistic else { return "0.0" }
        let set = Set(tokens)
        func has(_ words: String...) -> Bool { !set.isDisjoint(with: words) }
        if has("latitude", "lat") { return "19.4326" }
        if has("longitude", "lng", "lon", "long") { return "-99.1332" }
        if DefaultValueProvider.isAmount(tokens) { return "9.99" }
        if has("rating", "score", "stars") { return "4.5" }
        if has("percent", "percentage", "progress", "ratio", "opacity", "alpha") { return "0.5" }
        if has("width", "height", "size", "radius") { return "100.0" }
        return "0.0"
    }

    private func boolValue(tokens: [String]) -> Bool {
        guard style == .realistic, let first = tokens.first else { return false }
        return ["is", "has", "can", "should", "enabled", "active", "allow", "allowed", "verified", "available", "visible"].contains(first)
    }

    private func urlValue(tokens: [String]) -> String {
        let set = Set(tokens)
        if style == .realistic, !set.isDisjoint(with: ["image", "avatar", "photo", "thumbnail", "picture", "icon", "logo"]) {
            return "https://example.com/image.png"
        }
        return "https://example.com"
    }
}
