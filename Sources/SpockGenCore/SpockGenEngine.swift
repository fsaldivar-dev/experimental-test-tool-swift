import Foundation

/// Orquestador principal de SpockGen
public final class SpockGenEngine: Sendable {
    public struct Configuration: Sendable {
        public var sourcesDirectories: [String]
        public var testsDirectories: [String]
        public var outputPath: String
        public var cachePath: String?
        public var verbose: Bool

        public init(
            sourcesDirectories: [String],
            testsDirectories: [String],
            outputPath: String,
            cachePath: String? = nil,
            verbose: Bool = false
        ) {
            self.sourcesDirectories = sourcesDirectories
            self.testsDirectories = testsDirectories
            self.outputPath = outputPath
            self.cachePath = cachePath
            self.verbose = verbose
        }
    }

    public enum EngineResult: Sendable, Equatable {
        case upToDate(cachedModelsCount: Int)
        case generated(modelsCount: Int, outputPath: String)
        case noStubsFound
    }

    public let config: Configuration

    public init(config: Configuration) {
        self.config = config
    }

    /// Ejecuta el pipeline completo de inspección, resolución y generación
    @discardableResult
    public func run() throws -> EngineResult {
        let fileManager = FileManager.default

        // 1. Recolectar todos los archivos .swift
        let sourceFiles = collectSwiftFiles(in: config.sourcesDirectories)
        let testFiles = collectSwiftFiles(in: config.testsDirectories)
        let allInputFiles = (sourceFiles + testFiles).sorted()

        if config.verbose {
            print("[SpockGen] 🔍 Encontrados \(sourceFiles.count) archivos de fuentes y \(testFiles.count) de tests.")
        }

        // 2. Comprobar Caché Incremental
        let cacheManager: CacheManager?
        if let cachePath = config.cachePath {
            let manager = CacheManager(cacheFilePath: cachePath)
            cacheManager = manager

            if fileManager.fileExists(atPath: config.outputPath),
               manager.isCacheValid(for: allInputFiles, cachedManifest: manager.loadManifest()) {
                if config.verbose {
                    print("[SpockGen] ⚡ Cache HIT: Ningún archivo fuente o de test ha cambiado (< 5ms).")
                }
                return .upToDate(cachedModelsCount: allInputFiles.count)
            }
        } else {
            cacheManager = nil
        }

        // 3. Parsear Modelos de Producción y de Tests
        var availableModels: [String: ModelDefinition] = [:]

        for filePath in (sourceFiles + testFiles) {
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            let models = ModelParser.parse(source: content, filePath: filePath)
            for model in models {
                if availableModels[model.name] == nil {
                    availableModels[model.name] = model
                }
            }
        }

        // 4. Escanear Declaraciones @Stub en Tests
        var allDeclarations: [StubDeclaration] = []
        var allImports: [String] = []

        for filePath in testFiles {
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            let scanResult = TestScanner.scanDetailed(source: content, filePath: filePath)
            allDeclarations.append(contentsOf: scanResult.stubs)
            allImports.append(contentsOf: scanResult.imports)
        }

        if allDeclarations.isEmpty {
            if config.verbose {
                print("[SpockGen] ℹ️ No se encontraron anotaciones @Stub en los tests.")
            }
            return .noStubsFound
        }

        // 5. Deduplicación inteligente
        let tracker = SourceTracker()
        let trackingResult = tracker.process(declarations: allDeclarations)

        for warning in trackingResult.warnings {
            print("[SpockGen] ⚠️ Advertencia: \(warning)")
        }

        // 6. Resolución recursiva autoTree (A -> B -> C)
        let rootTypeNames = Array(trackingResult.activeStubs.keys)
        let resolver = AutoTreeResolver()
        let autoTreeResult = resolver.resolve(rootTypes: rootTypeNames, availableModels: availableModels)

        for cycle in autoTreeResult.detectedCycles {
            print("[SpockGen] ⚠️ Ciclo detectado en dependencias: \(cycle)")
        }

        // 7. Generar código Swift limpio
        let generator = CodeGenerator()
        let generatedSwift = generator.generate(
            models: autoTreeResult.modelsToGenerate,
            availableModels: availableModels,
            imports: allImports
        )

        // 8. Escribir resultado en outputPath
        let outputURL = URL(fileURLWithPath: config.outputPath)
        let parentDir = outputURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        try generatedSwift.write(to: outputURL, atomically: true, encoding: .utf8)

        // 9. Actualizar Manifiesto de Caché
        if let cacheManager = cacheManager {
            let manifest = cacheManager.createManifest(filePaths: allInputFiles, generatedCode: generatedSwift)
            try? cacheManager.saveManifest(manifest)
        }

        if config.verbose {
            print("[SpockGen] ✨ Stubs generados con éxito para \(autoTreeResult.modelsToGenerate.count) modelos en \(config.outputPath).")
        }

        return .generated(modelsCount: autoTreeResult.modelsToGenerate.count, outputPath: config.outputPath)
    }

    private func collectSwiftFiles(in directories: [String]) -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default

        for dir in directories {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: dir, isDirectory: &isDir) {
                if !isDir.boolValue && dir.hasSuffix(".swift") {
                    files.append(dir)
                    continue
                }

                guard let enumerator = fileManager.enumerator(atPath: dir) else { continue }
                while let element = enumerator.nextObject() as? String {
                    if element.hasSuffix(".swift") && !element.contains(".build") && !element.contains(".spock") && !element.hasSuffix(".generated.swift") {
                        let fullPath = (dir as NSString).appendingPathComponent(element)
                        files.append(fullPath)
                    }
                }
            }
        }

        return files
    }
}
