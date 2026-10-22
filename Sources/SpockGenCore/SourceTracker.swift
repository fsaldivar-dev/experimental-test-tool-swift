//
//  SourceTracker.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Resultado del rastreo y deduplicación de `@Stubbed`.
public struct TrackingResult: Sendable, Equatable {
    public let activeStubs: [String: StubDeclaration]
    public let ignoredDuplicates: [StubDeclaration]
    public let warnings: [String]

    public init(
        activeStubs: [String: StubDeclaration],
        ignoredDuplicates: [StubDeclaration],
        warnings: [String]
    ) {
        self.activeStubs = activeStubs
        self.ignoredDuplicates = ignoredDuplicates
        self.warnings = warnings
    }
}

/// Registra el archivo de origen de cada `@Stubbed` y descarta duplicados para evitar errores de compilación.
public final class SourceTracker: Sendable {
    public init() {}

    public func process(declarations: [StubDeclaration]) -> TrackingResult {
        var activeStubs: [String: StubDeclaration] = [:]
        var ignoredDuplicates: [StubDeclaration] = []
        var warnings: [String] = []

        for decl in declarations {
            guard let existing = activeStubs[decl.typeName] else {
                activeStubs[decl.typeName] = decl
                continue
            }
            // Una declaración explícita sustituye a un descubrimiento implícito sin avisar.
            if decl.isExplicit, !existing.isExplicit {
                activeStubs[decl.typeName] = decl
                continue
            }
            // Un descubrimiento implícito repetido no es un duplicado del usuario.
            guard decl.isExplicit, existing.isExplicit else { continue }

            ignoredDuplicates.append(decl)
            let warn = "[SpockSwift] @Stubbed \(decl.typeName) declarado en \(decl.declaredInFile) fue omitido porque ya fue registrado por \(existing.declaredInFile)."
            warnings.append(warn)
        }

        return TrackingResult(
            activeStubs: activeStubs,
            ignoredDuplicates: ignoredDuplicates,
            warnings: warnings
        )
    }
}
