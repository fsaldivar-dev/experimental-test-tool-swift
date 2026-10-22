import Foundation
import CryptoKit

/// Manifiesto de caché: hashes de las entradas y de cada archivo generado.
public struct SpockCacheManifest: Codable, Sendable, Equatable {
    /// Versión del formato de salida. Súbela cuando cambie lo que spock-gen escribe:
    /// un manifiesto con otra versión nunca es un cache hit, aunque nada más haya cambiado.
    public static let currentVersion = "2.5.0"

    public var version: String
    /// Ruta de entrada -> sha256 del contenido.
    public var fileHashes: [String: String]
    /// Hash del archivo único de salida (formato legado).
    public var outputHash: String?
    /// Nombres de modelos generados (formato legado).
    public var generatedModels: [String]
    /// Ruta relativa a la carpeta de salida -> sha256 del contenido generado.
    public var generatedFiles: [String: String]

    public init(
        version: String = SpockCacheManifest.currentVersion,
        fileHashes: [String: String] = [:],
        outputHash: String? = nil,
        generatedModels: [String] = [],
        generatedFiles: [String: String] = [:]
    ) {
        self.version = version
        self.fileHashes = fileHashes
        self.outputHash = outputHash
        self.generatedModels = generatedModels
        self.generatedFiles = generatedFiles
    }

    enum CodingKeys: String, CodingKey {
        case version
        case fileHashes
        case outputHash
        case generatedModels
        case generatedFiles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "2.0.0"
        self.fileHashes = try container.decodeIfPresent([String: String].self, forKey: .fileHashes) ?? [:]
        self.outputHash = try container.decodeIfPresent(String.self, forKey: .outputHash)
        self.generatedModels = try container.decodeIfPresent([String].self, forKey: .generatedModels) ?? []
        self.generatedFiles = try container.decodeIfPresent([String: String].self, forKey: .generatedFiles) ?? [:]
    }
}

/// Administrador de caché incremental: evita volver a parsear cuando nada cambió.
public final class CacheManager: Sendable {
    public let cacheFilePath: String

    public init(cacheFilePath: String) {
        self.cacheFilePath = cacheFilePath
    }

    /// Carga el manifiesto existente desde disco si existe
    public func loadManifest() -> SpockCacheManifest? {
        let url = URL(fileURLWithPath: cacheFilePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(SpockCacheManifest.self, from: data)
    }

    /// Guarda el manifiesto en disco
    public func saveManifest(_ manifest: SpockCacheManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let url = URL(fileURLWithPath: cacheFilePath)

        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        try data.write(to: url, options: .atomic)
    }

    /// Calcula el hash SHA256 de una cadena de texto
    public func hash(string: String) -> String {
        let data = Data(string.utf8)
        return hash(data: data)
    }

    /// Calcula el hash SHA256 de un bloque de datos
    public func hash(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Calcula el hash SHA256 de un archivo en disco
    public func hash(fileAt path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return hash(data: data)
    }

    /// `true` solo si todas las entradas existen con el mismo hash que el manifiesto.
    private func inputsMatch(_ filePaths: [String], manifest: SpockCacheManifest) -> Bool {
        guard manifest.fileHashes.count == filePaths.count else { return false }
        for path in filePaths {
            guard let cachedHash = manifest.fileHashes[path],
                  let currentHash = hash(fileAt: path),
                  cachedHash == currentHash else {
                return false
            }
        }
        return true
    }

    /// Evalúa si el caché es válido para una lista de archivos fuente y opcionalmente un archivo único de salida.
    public func isCacheValid(
        for filePaths: [String],
        outputPath: String? = nil,
        cachedManifest: SpockCacheManifest?
    ) -> Bool {
        guard let manifest = cachedManifest, inputsMatch(filePaths, manifest: manifest) else { return false }

        if let outputPath = outputPath {
            guard FileManager.default.fileExists(atPath: outputPath),
                  let cachedOutputHash = manifest.outputHash,
                  let currentOutputHash = hash(fileAt: outputPath),
                  cachedOutputHash == currentOutputHash else {
                return false
            }
        }

        return true
    }

    /// Evalúa si el caché es válido para las entradas y para la carpeta de salida completa:
    /// cada archivo generado del manifiesto existe con el mismo hash y no hay archivos de más.
    public func isCacheValid(
        for filePaths: [String],
        layout: OutputLayout,
        cachedManifest: SpockCacheManifest?
    ) -> Bool {
        guard let manifest = cachedManifest,
              manifest.version == SpockCacheManifest.currentVersion,
              inputsMatch(filePaths, manifest: manifest) else { return false }

        let existing = Set(layout.existingGeneratedFiles())
        guard existing == Set(manifest.generatedFiles.keys) else { return false }

        for (relativePath, cachedHash) in manifest.generatedFiles {
            guard let currentHash = hash(fileAt: layout.absolutePath(relative: relativePath)),
                  currentHash == cachedHash else {
                return false
            }
        }
        return true
    }

    /// Manifiesto para el formato legado de archivo único.
    public func createManifest(
        filePaths: [String],
        generatedCode: String,
        generatedModels: [String] = []
    ) -> SpockCacheManifest {
        SpockCacheManifest(
            version: "2.0.0",
            fileHashes: inputHashes(filePaths),
            outputHash: hash(string: generatedCode),
            generatedModels: generatedModels
        )
    }

    /// Manifiesto para la carpeta de salida: `generatedFiles` es ruta relativa -> contenido generado.
    public func createManifest(
        filePaths: [String],
        generatedFiles: [String: String]
    ) -> SpockCacheManifest {
        var outputHashes: [String: String] = [:]
        for (relativePath, content) in generatedFiles {
            outputHashes[relativePath] = hash(string: content)
        }
        let models = generatedFiles.keys
            .map { OutputLayout.typeName(fromGeneratedFile: $0) }
            .sorted()
        return SpockCacheManifest(
            version: SpockCacheManifest.currentVersion,
            fileHashes: inputHashes(filePaths),
            outputHash: nil,
            generatedModels: models,
            generatedFiles: outputHashes
        )
    }

    private func inputHashes(_ filePaths: [String]) -> [String: String] {
        var hashes: [String: String] = [:]
        for path in filePaths {
            if let fileHash = hash(fileAt: path) {
                hashes[path] = fileHash
            }
        }
        return hashes
    }
}
