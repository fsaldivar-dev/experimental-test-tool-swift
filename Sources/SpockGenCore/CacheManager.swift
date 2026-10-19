import Foundation
import CryptoKit

public struct SpockCacheManifest: Codable, Sendable, Equatable {
    public var version: String
    public var fileHashes: [String: String] // ruta o identificador -> sha256
    public var outputHash: String?
    public var generatedModels: [String]

    public init(
        version: String = "2.0.0",
        fileHashes: [String: String] = [:],
        outputHash: String? = nil,
        generatedModels: [String] = []
    ) {
        self.version = version
        self.fileHashes = fileHashes
        self.outputHash = outputHash
        self.generatedModels = generatedModels
    }

    enum CodingKeys: String, CodingKey {
        case version
        case fileHashes
        case outputHash
        case generatedModels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "2.0.0"
        self.fileHashes = try container.decodeIfPresent([String: String].self, forKey: .fileHashes) ?? [:]
        self.outputHash = try container.decodeIfPresent(String.self, forKey: .outputHash)
        self.generatedModels = try container.decodeIfPresent([String].self, forKey: .generatedModels) ?? []
    }
}

/// Administrador de caché incremental para optimizar builds sucesivos en < 5ms
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

    /// Evalúa si el caché es válido para una lista de archivos fuente
    /// Devuelve `true` únicamente si todos los archivos existen y sus hashes coinciden exactamente con el manifiesto.
    public func isCacheValid(
        for filePaths: [String],
        cachedManifest: SpockCacheManifest?
    ) -> Bool {
        guard let manifest = cachedManifest else { return false }

        // Si la cantidad de archivos cambió, el caché está invalidado
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

    /// Construye un nuevo manifiesto a partir de una lista de archivos, el contenido generado y los modelos generados
    public func createManifest(
        filePaths: [String],
        generatedCode: String,
        generatedModels: [String] = []
    ) -> SpockCacheManifest {
        var hashes: [String: String] = [:]
        for path in filePaths {
            if let fileHash = hash(fileAt: path) {
                hashes[path] = fileHash
            }
        }
        let codeHash = hash(string: generatedCode)
        return SpockCacheManifest(
            version: "2.0.0",
            fileHashes: hashes,
            outputHash: codeHash,
            generatedModels: generatedModels
        )
    }
}
