//
//  OutputLayout.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Dónde vive cada stub generado dentro de la carpeta de salida.
///
/// La carpeta refleja la estructura del módulo de origen, así el stub de
/// `Data/Entities/User.swift` del módulo `App` queda en
/// `Generated/App/Data/Entities/Stubs/User+Stub.swift`.
public struct OutputLayout: Sendable, Equatable {
    /// Sufijo que identifica a un archivo generado por spock-gen.
    public static let fileSuffix = "+Stub.swift"
    /// Carpeta hoja que agrupa los stubs de un directorio de origen.
    public static let stubsFolder = "Stubs"

    public let rootDirectory: String

    public init(rootDirectory: String) {
        self.rootDirectory = SourceRoot.normalize(rootDirectory)
    }

    /// Ruta del stub relativa a la raíz: `<module>/<ruta relativa>/Stubs/<Tipo>+Stub.swift`.
    public func relativePath(for model: ModelDefinition) -> String {
        var components: [String] = [model.module.isEmpty ? "Unknown" : model.module]
        components.append(contentsOf: model.relativeDirectory
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." })
        components.append(OutputLayout.stubsFolder)
        components.append(model.name + OutputLayout.fileSuffix)
        return components.joined(separator: "/")
    }

    public func absolutePath(for model: ModelDefinition) -> String {
        absolutePath(relative: relativePath(for: model))
    }

    public func absolutePath(relative: String) -> String {
        rootDirectory + "/" + relative
    }

    /// Archivos generados que existen hoy bajo la raíz, como rutas relativas ordenadas.
    public func existingGeneratedFiles() -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: rootDirectory) else { return [] }
        var files: [String] = []
        while let element = enumerator.nextObject() as? String {
            if element.hasSuffix(OutputLayout.fileSuffix) {
                files.append(element)
            }
        }
        return files.sorted()
    }

    /// Elimina los directorios que quedaron vacíos bajo la raíz, incluida la raíz misma.
    public func removeEmptyDirectories() {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: rootDirectory) else { return }
        var directories: [String] = []
        while let element = enumerator.nextObject() as? String {
            var isDirectory: ObjCBool = false
            let full = absolutePath(relative: element)
            if fileManager.fileExists(atPath: full, isDirectory: &isDirectory), isDirectory.boolValue {
                directories.append(full)
            }
        }
        // De la más profunda a la más superficial, y al final la raíz.
        for directory in directories.sorted(by: { $0.count > $1.count }) + [rootDirectory] {
            if let contents = try? fileManager.contentsOfDirectory(atPath: directory),
               contents.filter({ $0 != ".DS_Store" }).isEmpty {
                try? fileManager.removeItem(atPath: directory)
            }
        }
    }
}
