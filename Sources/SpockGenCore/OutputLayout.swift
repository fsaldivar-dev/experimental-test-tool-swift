//
//  OutputLayout.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Dónde vive cada archivo generado dentro de la carpeta de salida.
///
/// La carpeta refleja la estructura del módulo de origen, así el stub de
/// `Data/Entities/User.swift` del módulo `App` queda en
/// `Generated/App/Data/Entities/Stubs/User+Stub.swift`, y el mock de
/// `Data/Services/UserRepository.swift` en `Generated/App/Data/Services/Mocks/UserRepository+Mock.swift`.
public struct OutputLayout: Sendable, Equatable {
    /// Sufijo de un stub generado por spock-gen.
    public static let fileSuffix = "+Stub.swift"
    /// Sufijo de un mock generado por spock-gen.
    public static let mockFileSuffix = "+Mock.swift"
    /// Sufijo de un espía generado por spock-gen.
    public static let spyFileSuffix = "+Spy.swift"
    /// Todo lo que spock-gen reconoce como suyo.
    public static let generatedSuffixes = [fileSuffix, mockFileSuffix, spyFileSuffix]
    /// Carpetas hoja que agrupan lo generado por directorio de origen.
    public static let stubsFolder = "Stubs"
    public static let mocksFolder = "Mocks"
    public static let spiesFolder = "Spies"

    public let rootDirectory: String

    public init(rootDirectory: String) {
        self.rootDirectory = SourceRoot.normalize(rootDirectory)
    }

    /// Ruta del stub relativa a la raíz: `<module>/<ruta relativa>/Stubs/<Tipo>+Stub.swift`.
    public func relativePath(for model: ModelDefinition) -> String {
        relativePath(module: model.module, relativeDirectory: model.relativeDirectory, folder: OutputLayout.stubsFolder, fileName: model.name + OutputLayout.fileSuffix)
    }

    /// Ruta del mock relativa a la raíz: `<module>/<ruta relativa>/Mocks/<Protocolo>+Mock.swift`.
    public func relativePath(for definition: ProtocolDefinition) -> String {
        relativePath(module: definition.module, relativeDirectory: definition.relativeDirectory, folder: OutputLayout.mocksFolder, fileName: definition.name + OutputLayout.mockFileSuffix)
    }

    /// Ruta del espía relativa a la raíz: `<module>/<ruta relativa>/Spies/<Tipo>+Spy.swift`.
    public func relativePath(for implementation: ImplementationDefinition) -> String {
        relativePath(module: implementation.module, relativeDirectory: implementation.relativeDirectory, folder: OutputLayout.spiesFolder, fileName: implementation.name + OutputLayout.spyFileSuffix)
    }

    private func relativePath(module: String, relativeDirectory: String, folder: String, fileName: String) -> String {
        var components: [String] = [module.isEmpty ? "Unknown" : module]
        components.append(contentsOf: relativeDirectory
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." })
        components.append(folder)
        components.append(fileName)
        return components.joined(separator: "/")
    }

    public func absolutePath(for model: ModelDefinition) -> String {
        absolutePath(relative: relativePath(for: model))
    }

    public func absolutePath(relative: String) -> String {
        rootDirectory + "/" + relative
    }

    /// `true` si el nombre lleva alguno de los sufijos de spock-gen.
    public static func isGeneratedFile(_ path: String) -> Bool {
        generatedSuffixes.contains { path.hasSuffix($0) }
    }

    /// Nombre del tipo a partir de un archivo generado: `User+Stub.swift` -> `User`.
    public static func typeName(fromGeneratedFile path: String) -> String {
        var name = (path as NSString).lastPathComponent
        for suffix in generatedSuffixes where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name
    }

    /// Archivos generados que existen hoy bajo la raíz, como rutas relativas ordenadas.
    public func existingGeneratedFiles() -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: rootDirectory) else { return [] }
        var files: [String] = []
        while let element = enumerator.nextObject() as? String {
            if OutputLayout.isGeneratedFile(element) {
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
