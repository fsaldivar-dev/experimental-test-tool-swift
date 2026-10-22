import Foundation

/// Orquestador de SpockGen.
///
/// Los stubs y mocks se tratan como snapshots: `run()` los escribe en la carpeta de salida para
/// versionarlos junto a los tests, `check()` detecta si quedaron desfasados respecto al
/// dominio, y `clean()` los elimina. Nada se regenera en tiempo de build.
public final class SpockGenEngine: Sendable {
    public struct Configuration: Sendable {
        /// Módulos de producción, cada uno con la raíz de sus fuentes.
        public var sourceRoots: [SourceRoot]
        /// Módulos de tests, donde viven las declaraciones `@Stubbed` / `@Mocking` / `@Spied` y los modelos locales.
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
        /// Modelos con stub (incluye los descubiertos por autoTree).
        public let models: [ModelDefinition]
        /// Protocolos con mock.
        public let protocols: [ProtocolDefinition]
        /// Implementaciones con espía.
        public let spies: [ImplementationDefinition]
        public let files: [String: String]
        public let inputFiles: [String]
        public let warnings: [String]
        public let detectedCycles: [String]
    }

    /// Resultado de `check()`: rutas relativas a la carpeta de salida.
    public struct CheckResult: Sendable, Equatable {
        /// Archivos que deberían existir y no están en disco.
        public let missing: [String]
        /// Archivos cuyo contenido en disco ya no coincide con el dominio.
        public let stale: [String]
        /// Archivos generados en disco que ya no corresponden a ningún modelo ni protocolo.
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

    /// Inspecciona dominio y tests, resuelve autoTree y genera el contenido de cada archivo sin tocar el disco.
    public func plan() throws -> GenerationPlan {
        let sourceFiles = collectSwiftFiles(in: config.sourceRoots)
        let testFiles = collectSwiftFiles(in: config.testRoots)
        let inputFiles = (sourceFiles + testFiles).map(\.path).sorted()

        log("🔍 Encontrados \(sourceFiles.count) archivos de fuentes y \(testFiles.count) de tests.")

        // 1. Modelos y protocolos disponibles: dominio y declarados en tests.
        //    Solo los del dominio se descubren implícitamente por uso; un struct declarado en tests
        //    (un Error, un helper) necesita @Stubbed explícito para recibir stub.
        var availableModels: [String: ModelDefinition] = [:]
        var availableProtocols: [String: ProtocolDefinition] = [:]
        var availableImplementations: [String: ImplementationDefinition] = [:]
        var extensionsByType: [String: [ImplementationDefinition]] = [:]
        var domainModelNames: Set<String> = []
        for input in sourceFiles + testFiles {
            guard let content = try? String(contentsOfFile: input.path, encoding: .utf8) else { continue }
            let parsed = ModelParser.parseAll(
                source: content,
                filePath: input.path,
                module: input.root.module,
                relativeDirectory: input.root.relativeDirectory(of: input.path) ?? ""
            )
            let isDomain = sourceFiles.contains { $0.path == input.path }
            for model in parsed.models where availableModels[model.name] == nil {
                availableModels[model.name] = model
                if isDomain { domainModelNames.insert(model.name) }
            }
            for definition in parsed.protocols where availableProtocols[definition.name] == nil {
                availableProtocols[definition.name] = definition
            }
            for implementation in parsed.implementations {
                if implementation.kind == .extension {
                    extensionsByType[implementation.name, default: []].append(implementation)
                } else if availableImplementations[implementation.name] == nil {
                    availableImplementations[implementation.name] = implementation
                }
            }
        }

        // 2. Declaraciones @Stubbed / @Mocking, llamadas .stub() y modelos usados en tests
        var declarations: [StubDeclaration] = []
        var imports: [String] = []
        let knownModelNames = domainModelNames
        for input in testFiles {
            guard let content = try? String(contentsOfFile: input.path, encoding: .utf8) else { continue }
            let scan = TestScanner.scanDetailed(source: content, filePath: input.path, knownModelNames: knownModelNames)
            declarations.append(contentsOf: scan.stubs)
            imports.append(contentsOf: scan.imports)
        }

        guard !declarations.isEmpty else {
            return GenerationPlan(models: [], protocols: [], spies: [], files: [:], inputFiles: inputFiles, warnings: [], detectedCycles: [])
        }

        // 3. Deduplicación
        let tracking = SourceTracker().process(declarations: declarations)
        var warnings = tracking.warnings
        let active = tracking.activeStubs.values.sorted { $0.typeName < $1.typeName }

        // 4. Mocks: resolver protocolos (con sus padres) y anotar los tipos que sus stubs deben cubrir
        let layout = config.layout
        let mockGenerator = MockGenerator()
        var files: [String: String] = [:]
        var mockedProtocols: [ProtocolDefinition] = []
        var typesNeededByMocks: [String] = []

        for declaration in active where declaration.kind == .mock {
            guard let definition = availableProtocols[declaration.typeName] else {
                warnings.append("@Mocking \(declaration.typeName) en \(declaration.declaredInFile): no se encontró un protocolo con ese nombre en las fuentes.")
                continue
            }
            let resolved = definition.merging(parents: parentProtocols(of: definition, in: availableProtocols))
            if !resolved.unsupportedRequirements.isEmpty {
                let unsupported = Set(resolved.unsupportedRequirements).sorted().joined(separator: ", ")
                warnings.append("@Mocking \(declaration.typeName): se omite porque tiene requisitos que el mock no puede satisfacer (\(unsupported)).")
                continue
            }
            mockedProtocols.append(resolved)
            typesNeededByMocks.append(contentsOf: MockGenerator.referencedTypes(in: resolved))
            files[layout.relativePath(for: resolved)] = mockGenerator.generateFile(
                for: resolved,
                availableModels: availableModels,
                imports: imports
            )
        }

        // 4b. Espías: envoltorios que registran y delegan en la implementación real
        let spyGenerator = SpyGenerator()
        var spiedImplementations: [ImplementationDefinition] = []
        for declaration in active where declaration.kind == .spy {
            guard let implementation = availableImplementations[declaration.typeName] else {
                warnings.append("@Spied \(declaration.typeName) en \(declaration.declaredInFile): no se encontró una clase, actor o struct con ese nombre en las fuentes.")
                continue
            }
            let merged = implementation.merging(extensions: extensionsByType[implementation.name] ?? [])
            let conformed = merged.inheritedTypes.compactMap { availableProtocols[$0] }
                .map { $0.merging(parents: parentProtocols(of: $0, in: availableProtocols)) }
            if conformed.isEmpty, merged.methods.isEmpty {
                warnings.append("@Spied \(declaration.typeName): no conforma a ningún protocolo conocido ni tiene métodos que espiar.")
                continue
            }
            spiedImplementations.append(merged)
            files[layout.relativePath(for: merged)] = spyGenerator.generateFile(
                for: merged,
                conforming: conformed,
                imports: imports
            )
        }

        // 5. Stubs: raíces explícitas e implícitas más lo que los mocks devuelven, y autoTree
        var rootTypes = active.filter { $0.kind == .stub }.map(\.typeName)
        for type in typesNeededByMocks where availableModels[type] != nil && !rootTypes.contains(type) {
            rootTypes.append(type)
        }
        rootTypes.sort()
        let tree = AutoTreeResolver().resolve(rootTypes: rootTypes, availableModels: availableModels)

        let generator = CodeGenerator()
        for model in tree.modelsToGenerate where !model.isEnum {
            files[layout.relativePath(for: model)] = generator.generateFile(
                for: model,
                availableModels: availableModels,
                imports: imports
            )
        }

        return GenerationPlan(
            models: tree.modelsToGenerate,
            protocols: mockedProtocols,
            spies: spiedImplementations,
            files: files,
            inputFiles: inputFiles,
            warnings: warnings,
            detectedCycles: tree.detectedCycles
        )
    }

    /// Escribe los archivos que cambiaron, elimina los huérfanos y actualiza el manifiesto.
    @discardableResult
    public func run() throws -> EngineResult {
        let fileManager = FileManager.default
        let layout = config.layout
        let cacheManager = config.cachePath.map { CacheManager(cacheFilePath: $0) }
        let cachedManifest = cacheManager?.loadManifest()

        if let cacheManager, let cachedManifest {
            let inputs = (collectSwiftFiles(in: config.sourceRoots) + collectSwiftFiles(in: config.testRoots)).map(\.path).sorted()
            if cacheManager.isCacheValid(for: inputs, layout: layout, cachedManifest: cachedManifest) {
                log("⚡ Cache HIT: ni las fuentes ni los archivos generados cambiaron.")
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
            print("[SpockGen] 🧹 Cleaner: archivos huérfanos eliminados: \(orphans.joined(separator: ", "))")
        }

        if let cacheManager {
            try? cacheManager.saveManifest(cacheManager.createManifest(filePaths: plan.inputFiles, generatedFiles: plan.files))
        }

        guard !plan.files.isEmpty else {
            log("ℹ️ No se encontraron anotaciones @Stubbed / @Mocking / @Spied ni modelos usados en tests.")
            return .noStubsFound
        }

        log("✨ \(plan.files.count) archivos al día en \(config.outputDirectory) (\(written.count) escritos, \(plan.protocols.count) mocks, \(plan.spies.count) espías).")
        return .generated(modelsCount: plan.models.count + plan.protocols.count + plan.spies.count, outputDirectory: config.outputDirectory)
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

    /// Elimina todos los archivos generados y el manifiesto de caché. Devuelve lo que borró.
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

    // MARK: - Protocolos

    /// Padres conocidos de un protocolo, recursivamente y sin ciclos.
    private func parentProtocols(of definition: ProtocolDefinition, in available: [String: ProtocolDefinition]) -> [ProtocolDefinition] {
        var visited: Set<String> = [definition.name]
        var result: [ProtocolDefinition] = []

        func visit(_ current: ProtocolDefinition) {
            for parentName in current.inheritedTypes {
                guard !visited.contains(parentName), let parent = available[parentName] else { continue }
                visited.insert(parentName)
                result.append(parent)
                visit(parent)
            }
        }

        visit(definition)
        return result
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
                if OutputLayout.isGeneratedFile(element) || element.hasSuffix(".generated.swift") { continue }
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
