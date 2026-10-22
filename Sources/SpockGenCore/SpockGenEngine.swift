import Foundation

/// Orquestador de SpockGen.
///
/// Los stubs se tratan como snapshots: `run()` los escribe en la carpeta de salida para
/// versionarlos junto a los tests, `check()` detecta si quedaron desfasados respecto al
/// dominio, y `clean()` los elimina. Nada se regenera en tiempo de build.
public final class SpockGenEngine: Sendable {
    public struct Configuration: Sendable {
        /// Módulos de producción, cada uno con la raíz de sus fuentes.
        public var sourceRoots: [SourceRoot]
        /// Módulos de tests, donde viven las declaraciones `@Stubbed` y los modelos locales.
        public var testRoots: [SourceRoot]
        /// Carpeta `Generated`, normalmente dentro del target de tests.
        public var outputDirectory: String
        public var cachePath: String?
        public var verbose: Bool

        public init(
            sourceRoots: [SourceRoot],
            testRoots: [SourceRoot],
            outputDirectory: String,
            cachePath: String? = nil,
            verbose: Bool = false
        ) {
            self.sourceRoots = sourceRoots
            self.testRoots = testRoots
            self.outputDirectory = SourceRoot.normalize(outputDirectory)
            self.cachePath = cachePath
            self.verbose = verbose
        }

        /// Infiere el nombre de cada módulo del último componente de su directorio.
        public init(
            sourcesDirectories: [String],
            testsDirectories: [String],
            outputDirectory: String,
            cachePath: String? = nil,
            verbose: Bool = false
        ) {
            self.init(
                sourceRoots: sourcesDirectories.map(SourceRoot.parse),
                testRoots: testsDirectories.map(SourceRoot.parse),
                outputDirectory: outputDirectory,
                cachePath: cachePath,
                verbose: verbose
            )
        }

        public var sourcesDirectories: [String] { sourceRoots.map(\.path) }
        public var testsDirectories: [String] { testRoots.map(\.path) }
        public var layout: OutputLayout { OutputLayout(rootDirectory: outputDirectory) }
    }

    public enum EngineResult: Sendable, Equatable {
        case upToDate(cachedModelsCount: Int)
        case generated(modelsCount: Int, outputDirectory: String)
        case noStubsFound
    }

    /// Lo que `run()` escribiría: contenido por ruta relativa a la carpeta de salida.
    public struct GenerationPlan: Sendable {
        public let models: [ModelDefinition]
        public let files: [String: String]
        public let inputFiles: [String]
        public let warnings: [String]
        public let detectedCycles: [String]
    }

    /// Resultado de `check()`: rutas relativas a la carpeta de salida.
    public struct CheckResult: Sendable, Equatable {
        /// Stubs que deberían existir y no están en disco.
        public let missing: [String]
        /// Stubs cuyo contenido en disco ya no coincide con el dominio.
        public let stale: [String]
        /// Archivos generados en disco que ya no corresponden a ningún modelo.
        public let orphaned: [String]

        public init(missing: [String], stale: [String], orphaned: [String]) {
            self.missing = missing
            self.stale = stale
            self.orphaned = orphaned
        }

        public var isUpToDate: Bool { missing.isEmpty && stale.isEmpty && orphaned.isEmpty }
    }

    public let config: Configuration

    public init(config: Configuration) {
        self.config = config
    }

    // MARK: - Pipeline

    /// Inspecciona dominio y tests, resuelve autoTree y genera el contenido de cada stub sin tocar el disco.
    public func plan() throws -> GenerationPlan {
        let sourceFiles = collectSwiftFiles(in: config.sourceRoots)
        let testFiles = collectSwiftFiles(in: config.testRoots)
        let inputFiles = (sourceFiles + testFiles).map(\.path).sorted()

        log("🔍 Encontrados \(sourceFiles.count) archivos de fuentes y \(testFiles.count) de tests.")

        // 1. Modelos disponibles: dominio y modelos declarados en tests
        var availableModels: [String: ModelDefinition] = [:]
        for input in sourceFiles + testFiles {
            guard let content = try? String(contentsOfFile: input.path, encoding: .utf8) else { continue }
            let models = ModelParser.parse(
                source: content,
                filePath: input.path,
                module: input.root.module,
                relativeDirectory: input.root.relativeDirectory(of: input.path) ?? ""
            )
            for model in models where availableModels[model.name] == nil {
                availableModels[model.name] = model
            }
        }

        // 2. Declaraciones @Stubbed, llamadas .stub() y modelos usados en tests
        var declarations: [StubDeclaration] = []
        var imports: [String] = []
        let knownModelNames = Set(availableModels.keys)
        for input in testFiles {
            guard let content = try? String(contentsOfFile: input.path, encoding: .utf8) else { continue }
            let scan = TestScanner.scanDetailed(source: content, filePath: input.path, knownModelNames: knownModelNames)
            declarations.append(contentsOf: scan.stubs)
            imports.append(contentsOf: scan.imports)
        }

        guard !declarations.isEmpty else {
            return GenerationPlan(models: [], files: [:], inputFiles: inputFiles, warnings: [], detectedCycles: [])
        }

        // 3. Deduplicación y autoTree
        let tracking = SourceTracker().process(declarations: declarations)
        let rootTypes = tracking.activeStubs.keys.sorted()
        let tree = AutoTreeResolver().resolve(rootTypes: rootTypes, availableModels: availableModels)

        // 4. Un archivo por modelo
        let layout = config.layout
        let generator = CodeGenerator()
        var files: [String: String] = [:]
        for model in tree.modelsToGenerate where !model.isEnum {
            files[layout.relativePath(for: model)] = generator.generateFile(
                for: model,
                availableModels: availableModels,
                imports: imports
            )
        }

        return GenerationPlan(
            models: tree.modelsToGenerate,
            files: files,
            inputFiles: inputFiles,
            warnings: tracking.warnings,
            detectedCycles: tree.detectedCycles
        )
    }

    /// Escribe los stubs que cambiaron, elimina los huérfanos y actualiza el manifiesto.
    @discardableResult
    public func run() throws -> EngineResult {
        let fileManager = FileManager.default
        let layout = config.layout
        let cacheManager = config.cachePath.map { CacheManager(cacheFilePath: $0) }
        let cachedManifest = cacheManager?.loadManifest()

        if let cacheManager, let cachedManifest {
            let inputs = (collectSwiftFiles(in: config.sourceRoots) + collectSwiftFiles(in: config.testRoots)).map(\.path).sorted()
            if cacheManager.isCacheValid(for: inputs, layout: layout, cachedManifest: cachedManifest) {
                log("⚡ Cache HIT: ni las fuentes ni los stubs generados cambiaron.")
                return .upToDate(cachedModelsCount: cachedManifest.generatedFiles.count)
            }
        }

        let plan = try plan()
        for warning in plan.warnings {
            print("[SpockGen] ⚠️ Advertencia: \(warning)")
        }
        for cycle in plan.detectedCycles {
            print("[SpockGen] ⚠️ Ciclo detectado en dependencias: \(cycle)")
        }

        let existing = Set(layout.existingGeneratedFiles())

        var written: [String] = []
        for (relativePath, content) in plan.files.sorted(by: { $0.key < $1.key }) {
            let absolutePath = layout.absolutePath(relative: relativePath)
            if let current = try? String(contentsOfFile: absolutePath, encoding: .utf8), current == content {
                continue
            }
            let parent = (absolutePath as NSString).deletingLastPathComponent
            try fileManager.createDirectory(atPath: parent, withIntermediateDirectories: true)
            try content.write(toFile: absolutePath, atomically: true, encoding: .utf8)
            written.append(relativePath)
        }

        let orphans = existing.subtracting(plan.files.keys).sorted()
        for relativePath in orphans {
            try? fileManager.removeItem(atPath: layout.absolutePath(relative: relativePath))
        }
        layout.removeEmptyDirectories()
        if !orphans.isEmpty {
            print("[SpockGen] 🧹 Cleaner: stubs huérfanos eliminados: \(orphans.joined(separator: ", "))")
        }

        if let cacheManager {
            try? cacheManager.saveManifest(cacheManager.createManifest(filePaths: plan.inputFiles, generatedFiles: plan.files))
        }

        guard !plan.files.isEmpty else {
            log("ℹ️ No se encontraron anotaciones @Stubbed ni modelos usados en tests.")
            return .noStubsFound
        }

        log("✨ \(plan.files.count) stubs al día en \(config.outputDirectory) (\(written.count) escritos).")
        return .generated(modelsCount: plan.models.count, outputDirectory: config.outputDirectory)
    }

    /// Compara lo que se generaría con lo que hay en disco, sin escribir nada.
    public func check() throws -> CheckResult {
        let layout = config.layout
        let plan = try plan()
        let existing = Set(layout.existingGeneratedFiles())

        var missing: [String] = []
        var stale: [String] = []
        for (relativePath, content) in plan.files {
            guard let current = try? String(contentsOfFile: layout.absolutePath(relative: relativePath), encoding: .utf8) else {
                missing.append(relativePath)
                continue
            }
            if current != content {
                stale.append(relativePath)
            }
        }
        let orphaned = existing.subtracting(plan.files.keys).sorted()

        return CheckResult(missing: missing.sorted(), stale: stale.sorted(), orphaned: orphaned)
    }

    /// Elimina todos los stubs generados y el manifiesto de caché. Devuelve lo que borró.
    @discardableResult
    public func clean() throws -> [String] {
        let fileManager = FileManager.default
        let layout = config.layout
        let existing = layout.existingGeneratedFiles()
        for relativePath in existing {
            try fileManager.removeItem(atPath: layout.absolutePath(relative: relativePath))
        }
        layout.removeEmptyDirectories()
        if let cachePath = config.cachePath {
            try? fileManager.removeItem(atPath: cachePath)
        }
        return existing
    }

    // MARK: - Entradas

    struct InputFile {
        let root: SourceRoot
        let path: String
    }

    private func collectSwiftFiles(in roots: [SourceRoot]) -> [InputFile] {
        let fileManager = FileManager.default
        let outputPrefix = config.outputDirectory + "/"
        var files: [InputFile] = []

        for root in roots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else { continue }

            if !isDirectory.boolValue {
                if root.path.hasSuffix(".swift") {
                    let parent = SourceRoot(module: root.module, path: (root.path as NSString).deletingLastPathComponent)
                    files.append(InputFile(root: parent, path: root.path))
                }
                continue
            }

            guard let enumerator = fileManager.enumerator(atPath: root.path) else { continue }
            while let element = enumerator.nextObject() as? String {
                guard element.hasSuffix(".swift") else { continue }
                if element.contains(".build") || element.contains(".spock") { continue }
                if element.hasSuffix(OutputLayout.fileSuffix) || element.hasSuffix(".generated.swift") { continue }
                let fullPath = root.path + "/" + element
                if fullPath.hasPrefix(outputPrefix) { continue }
                files.append(InputFile(root: root, path: fullPath))
            }
        }

        return files
    }

    private func log(_ message: String) {
        if config.verbose {
            print("[SpockGen] \(message)")
        }
    }
}
