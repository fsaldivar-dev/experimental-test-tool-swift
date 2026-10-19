//
//  AutoTreeResolver.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Resultado de la resolución recursiva del árbol de dependencias (`autoTree`).
public struct AutoTreeResult: Sendable, Equatable {
    /// Lista ordenada de modelos que necesitan generar stub (incluyendo hijos descubiertos).
    public let modelsToGenerate: [ModelDefinition]
    /// Tipos que fueron incluidos automáticamente a través del autoTree sin que el dev los pidiera explícitamente.
    public let autoDiscoveredTypes: [String]
    /// Ciclos detectados en el árbol (si los hubo).
    public let detectedCycles: [String]

    public init(
        modelsToGenerate: [ModelDefinition],
        autoDiscoveredTypes: [String],
        detectedCycles: [String]
    ) {
        self.modelsToGenerate = modelsToGenerate
        self.autoDiscoveredTypes = autoDiscoveredTypes
        self.detectedCycles = detectedCycles
    }
}

/// Resuelve el árbol de dependencias de forma recursiva ($A \rightarrow B \rightarrow C$),
/// garantizando que todos los hijos tengan su correspondiente `.stub()` disponible y detectando ciclos.
public final class AutoTreeResolver: Sendable {
    public init() {}

    public func resolve(
        rootTypes: [String],
        availableModels: [String: ModelDefinition]
    ) -> AutoTreeResult {
        var resolvedTypes = Set<String>()
        var orderedModels: [ModelDefinition] = []
        var autoDiscovered: [String] = []
        var cycles: [String] = []

        func visit(typeName: String, path: [String]) {
            if path.contains(typeName) {
                let cyclePath = (path + [typeName]).joined(separator: " -> ")
                cycles.append(cyclePath)
                return
            }

            guard let model = availableModels[typeName] else {
                return
            }

            if resolvedTypes.contains(typeName) {
                return
            }

            // Inspeccionar hijos primero para orden topológico (post-order traversal)
            let newPath = path + [typeName]
            for prop in model.properties {
                let childType = prop.typeName
                // Si el hijo es un struct conocido (no enum ni primitivo)
                if let childModel = availableModels[childType], !childModel.isEnum {
                    if !rootTypes.contains(childType) && !autoDiscovered.contains(childType) {
                        autoDiscovered.append(childType)
                    }
                    visit(typeName: childType, path: newPath)
                }
            }

            resolvedTypes.insert(typeName)
            orderedModels.append(model)
        }

        for root in rootTypes {
            visit(typeName: root, path: [])
        }

        return AutoTreeResult(
            modelsToGenerate: orderedModels,
            autoDiscoveredTypes: autoDiscovered,
            detectedCycles: cycles
        )
    }
}
