//
//  SourceTracker.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Resultado del rastreo y deduplicación de `@Stub`.
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

/// Registra el archivo de origen de cada `@Stub` y descarta duplicados para evitar errores de compilación.
public final class SourceTracker: Sendable {
    public init() {}

    public func process(declarations: [StubDeclaration]) -> TrackingResult {
        var activeStubs: [String: StubDeclaration] = [:]
        var ignoredDuplicates: [StubDeclaration] = []
        var warnings: [String] = []

        for decl in declarations {
            if let existing = activeStubs[decl.typeName] {
                ignoredDuplicates.append(decl)
                let warn = "[SpockSwift] @Stub \(decl.typeName) declarado en \(decl.declaredInFile) fue omitido porque ya fue registrado por \(existing.declaredInFile)."
                warnings.append(warn)
            } else {
                activeStubs[decl.typeName] = decl
            }
        }

        return TrackingResult(
            activeStubs: activeStubs,
            ignoredDuplicates: ignoredDuplicates,
            warnings: warnings
        )
    }
}
