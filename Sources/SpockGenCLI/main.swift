//
//  main.swift
//  spock-gen CLI
//
//  Created for SpockSwift 2.
//

import Foundation
import SpockGenCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// Desactivar buffer en bloque para que los logs se escriban inmediatamente en disco
setlinebuf(stdout)
setlinebuf(stderr)

// MARK: - Opciones

struct Options {
    var sources: [SourceRoot] = []
    var tests: [SourceRoot] = []
    var output: String?
    var cache: String? = ".spock-cache.json"
    var verbose = false
    var watch = false
    var syncXcode = true
}

func printUsage() {
    print("""
    Uso: spock-gen [comando] [opciones]

    Comandos:
      generate       (por defecto) Escribe los stubs en la carpeta de salida y elimina los huérfanos
      check          Verifica que los stubs estén al día con el dominio; sale con código 1 si hay desfase
      clean          Elimina los stubs generados y la caché
      daemon start   Inicia el demonio de observación en segundo plano (opcional)
      daemon stop    Detiene el demonio
      daemon status  Muestra el estado del demonio

    Opciones:
      --sources <Módulo=dir | dir> ...  Raíces de los módulos de producción
      --tests   <Módulo=dir | dir> ...  Raíces de los módulos de tests con declaraciones @Stubbed / @Mocking / @Spied
      --output  <dir>                   Carpeta de salida (por defecto <primer tests dir>/Generated)
      --cache   <ruta>                  Manifiesto de caché (por defecto .spock-cache.json)
      --watch, -w                       Observa cambios y regenera al guardar
      --no-xcode                        No sincroniza el .xcodeproj cercano a la carpeta de salida
      --verbose                         Imprime información detallada
      --help, -h                        Muestra esta ayuda

    Un `dir` sin módulo toma el nombre de su último componente. Si el último componente es
    `Sources` o `Tests`, cada subcarpeta se registra como un módulo (convención de SwiftPM).

    La salida refleja la estructura del módulo de origen:
      <output>/<Módulo>/<ruta relativa>/Stubs/<Tipo>+Stub.swift
      <output>/<Módulo>/<ruta relativa>/Mocks/<Protocolo>+Mock.swift
      <output>/<Módulo>/<ruta relativa>/Spies/<Tipo>+Spy.swift

    Ejemplos:
      spock-gen --sources Example=Example/Example --tests ExampleTests=Example/ExampleTests
      spock-gen check --sources Sources --tests Tests
      spock-gen clean
    """)
}

/// `Sources` o `Tests` como raíz: una entrada por subcarpeta, con el nombre de la subcarpeta como módulo.
func expandRoots(_ spec: String) -> [SourceRoot] {
    if spec.contains("=") {
        return [SourceRoot.parse(spec)]
    }
    let root = SourceRoot.parse(spec)
    let last = (root.path as NSString).lastPathComponent
    guard last == "Sources" || last == "Tests" else { return [root] }

    let fileManager = FileManager.default
    guard let entries = try? fileManager.contentsOfDirectory(atPath: root.path) else { return [root] }
    let modules = entries.sorted().compactMap { entry -> SourceRoot? in
        var isDirectory: ObjCBool = false
        let path = root.path + "/" + entry
        guard !entry.hasPrefix("."), fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return SourceRoot(module: entry, path: path)
    }
    return modules.isEmpty ? [root] : modules
}

func parseOptions(_ args: [String]) -> Options {
    var options = Options()
    var currentFlag: String?

    for arg in args {
        switch arg {
        case "--sources", "--tests", "--output", "--cache":
            currentFlag = arg
        case "--verbose":
            options.verbose = true
            currentFlag = nil
        case "--watch", "-w":
            options.watch = true
            currentFlag = nil
        case "--no-xcode":
            options.syncXcode = false
            currentFlag = nil
        default:
            switch currentFlag {
            case "--sources":
                options.sources.append(contentsOf: expandRoots(arg))
            case "--tests":
                options.tests.append(contentsOf: expandRoots(arg))
            case "--output":
                options.output = arg
                currentFlag = nil
            case "--cache":
                options.cache = arg
                currentFlag = nil
            default:
                print("⚠️ Argumento ignorado: \(arg)")
            }
        }
    }
    return options
}

/// Rellena lo que falte con la convención del repositorio (Example) o de SwiftPM (Sources/Tests).
func autoDetect(into options: inout Options) {
    let fileManager = FileManager.default

    if options.sources.isEmpty {
        if fileManager.fileExists(atPath: "Example/Example/Domain") {
            options.sources = [SourceRoot(module: "Example", path: "Example/Example")]
        } else if fileManager.fileExists(atPath: "Sources") {
            options.sources = expandRoots("Sources")
        }
    }

    if options.tests.isEmpty {
        if fileManager.fileExists(atPath: "Example/ExampleTests") {
            options.tests = [SourceRoot(module: "ExampleTests", path: "Example/ExampleTests")]
        } else if fileManager.fileExists(atPath: "Tests") {
            options.tests = expandRoots("Tests")
        }
    }

    if options.output == nil, let firstTests = options.tests.first {
        options.output = firstTests.path + "/Generated"
    }
}

func describeCommand(_ options: Options, command: String = "") -> String {
    var parts = ["spock-gen"]
    if !command.isEmpty { parts.append(command) }
    parts.append("--sources")
    parts.append(contentsOf: options.sources.map(\.spec))
    parts.append("--tests")
    parts.append(contentsOf: options.tests.map(\.spec))
    if let output = options.output {
        parts.append(contentsOf: ["--output", output])
    }
    return parts.joined(separator: " ")
}

func makeConfiguration(_ options: Options) -> SpockGenEngine.Configuration? {
    guard !options.sources.isEmpty else {
        print("❌ Error: Debes especificar al menos una raíz de fuentes con --sources.")
        return nil
    }
    guard !options.tests.isEmpty else {
        print("❌ Error: Debes especificar al menos una raíz de tests con --tests.")
        return nil
    }
    guard let output = options.output else {
        print("❌ Error: Debes especificar la carpeta de salida con --output.")
        return nil
    }
    return SpockGenEngine.Configuration(
        sourceRoots: options.sources,
        testRoots: options.tests,
        outputDirectory: output,
        cachePath: options.cache,
        verbose: options.verbose
    )
}

/// Si hay un .xcodeproj cerca de la carpeta de salida, refleja en él los archivos generados
/// y la fase de script que los regenera cuando faltan.
func syncXcodeProject(_ options: Options, config: SpockGenEngine.Configuration) {
    guard options.syncXcode,
          let pbxPath = XcodeProjectIntegrator.findXcodeProject(nearPath: config.outputDirectory),
          let testModule = options.tests.first?.module else { return }

    // La fase regenera y, si Xcode borró las referencias al borrar los archivos, las restaura.
    let request = XcodeProjectIntegrator.SyncRequest(
        projectPbxprojPath: pbxPath,
        targetName: testModule,
        generatedDirectory: config.outputDirectory,
        generateCommand: "/usr/bin/swift run " + describeCommand(options)
    )
    do {
        switch try XcodeProjectIntegrator.sync(request) {
        case .synchronized(let count):
            print("🛠️ SpockGen: \(pbxPath) sincronizado (\(count) archivos generados referenciados).")
        case .upToDate:
            break
        case .targetNotFound(let name):
            print("⚠️ SpockGen: no se encontró el target \(name) en \(pbxPath); el proyecto no se tocó.")
        case .parentGroupNotFound(let name):
            print("⚠️ SpockGen: no se encontró el grupo \(name) en \(pbxPath); el proyecto no se tocó.")
        case .noProjectFound:
            break
        }
    } catch {
        print("⚠️ SpockGen: no se pudo sincronizar \(pbxPath): \(error.localizedDescription)")
    }
}

/// Metadata con rutas absolutas para la extensión de Xcode.
func persistProjectMetadata(_ options: Options, output: String) {
    let cwd = FileManager.default.currentDirectoryPath
    func absolute(_ path: String) -> String {
        (path as NSString).isAbsolutePath ? path : URL(fileURLWithPath: cwd).appendingPathComponent(path).standardized.path
    }
    let metadata: [String: Any] = [
        "projectRoot": cwd,
        "outputDirectory": absolute(output),
        "sources": options.sources.map { "\($0.module)=\(absolute($0.path))" },
        "tests": options.tests.map { "\($0.module)=\(absolute($0.path))" },
        "timestamp": Date().timeIntervalSince1970
    ]
    if let data = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted) {
        try? data.write(to: URL(fileURLWithPath: "/tmp/.spock_active_project.json"))
    }
}

// MARK: - Comandos

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("-h") || arguments.contains("--help") {
    printUsage()
    exit(0)
}

var command = "generate"
var optionArguments = arguments
if let first = arguments.first, !first.hasPrefix("-") {
    command = first
    optionArguments = Array(arguments.dropFirst())
}
if optionArguments.contains("--check") {
    command = "check"
    optionArguments.removeAll { $0 == "--check" }
}

func runGenerate(engine: SpockGenEngine) {
    do {
        let result = try engine.run()
        switch result {
        case .upToDate:
            if engine.config.verbose {
                print("⚡ SpockGen: Stubs al día (caché).")
            }
        case .generated(let count, let directory):
            print("✅ SpockGen: \(count) stubs, mocks y espías al día en \(directory)")
        case .noStubsFound:
            if engine.config.verbose {
                print("ℹ️ SpockGen: No se encontraron anotaciones @Stubbed activas.")
            }
        }
    } catch {
        print("❌ Error en SpockGen: \(error.localizedDescription)")
    }
}

switch command {
case "daemon":
    let subcommand = optionArguments.first ?? "status"
    let daemon = DaemonManager()

    switch subcommand {
    case "status":
        let status = daemon.status()
        if status.isRunning, let pid = status.pid {
            print("🟢 SpockGen Daemon está ACTIVO (PID: \(pid)).")
            print("📝 Archivo de log: \(status.logFilePath ?? ".spock-daemon.log")")
        } else {
            print("⚪ SpockGen Daemon está DETENIDO.")
        }
        exit(0)

    case "stop":
        if daemon.stop() {
            print("🛑 SpockGen Daemon detenido exitosamente.")
        } else {
            print("ℹ️ SpockGen Daemon no estaba en ejecución.")
        }
        exit(0)

    case "start":
        if let pid = daemon.status().pid, daemon.status().isRunning {
            print("⚠️ SpockGen Daemon ya está activo con PID \(pid).")
            exit(0)
        }

        var options = parseOptions(Array(optionArguments.dropFirst()))
        autoDetect(into: &options)
        guard let output = options.output, !options.sources.isEmpty, !options.tests.isEmpty else {
            print("❌ Error: Especifica --sources, --tests y --output para iniciar el demonio.")
            exit(1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        var passArgs = ["--sources"] + options.sources.map(\.spec)
        passArgs += ["--tests"] + options.tests.map(\.spec)
        passArgs += ["--output", output, "--watch"]
        if let cache = options.cache { passArgs += ["--cache", cache] }
        if options.verbose { passArgs.append("--verbose") }
        process.arguments = passArgs

        let logURL = URL(fileURLWithPath: daemon.logFilePath)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        if let fileHandle = try? FileHandle(forWritingTo: logURL) {
            fileHandle.seekToEndOfFile()
            process.standardOutput = fileHandle
            process.standardError = fileHandle
        }

        do {
            try process.run()
            try daemon.savePid(process.processIdentifier)
            print("🚀 SpockGen Daemon iniciado con PID \(process.processIdentifier).")
            print("👀 Observando cambios en:")
            for root in options.sources { print("   - [Sources] \(root.spec)") }
            for root in options.tests { print("   - [Tests]   \(root.spec)") }
            print("📁 Salida: \(output)")
            print("📝 Log:    \(daemon.logFilePath)")
            exit(0)
        } catch {
            print("❌ Error al iniciar el demonio: \(error.localizedDescription)")
            exit(1)
        }

    default:
        print("❌ Subcomando desconocido: '\(subcommand)'. Usa 'start', 'stop' o 'status'.")
        exit(1)
    }

case "clean":
    var options = parseOptions(optionArguments)
    autoDetect(into: &options)
    guard let config = makeConfiguration(options) else { exit(1) }
    do {
        let removed = try SpockGenEngine(config: config).clean()
        if removed.isEmpty {
            print("🧹 SpockGen Clean: no había stubs generados en \(config.outputDirectory).")
        } else {
            print("🧹 SpockGen Clean: \(removed.count) stubs eliminados de \(config.outputDirectory).")
            for path in removed { print("   - \(path)") }
        }
        syncXcodeProject(options, config: config)
        print("✅ SpockGen limpiado exitosamente.")
        exit(0)
    } catch {
        print("❌ Error durante clean: \(error.localizedDescription)")
        exit(1)
    }

case "check":
    var options = parseOptions(optionArguments)
    autoDetect(into: &options)
    guard let config = makeConfiguration(options) else { exit(1) }
    do {
        let result = try SpockGenEngine(config: config).check()
        if result.isUpToDate {
            print("✅ SpockGen: los stubs en \(config.outputDirectory) están al día.")
            exit(0)
        }
        print("❌ SpockGen: los stubs en \(config.outputDirectory) no están al día.")
        if !result.missing.isEmpty {
            print("   Faltan:")
            for path in result.missing { print("     - \(path)") }
        }
        if !result.stale.isEmpty {
            print("   Desfasados respecto al dominio:")
            for path in result.stale { print("     - \(path)") }
        }
        if !result.orphaned.isEmpty {
            print("   Huérfanos (sin @Stubbed, @Mocking ni @Spied que los pida):")
            for path in result.orphaned { print("     - \(path)") }
        }
        print("   Regenera con: \(describeCommand(options))")
        exit(1)
    } catch {
        print("❌ Error durante check: \(error.localizedDescription)")
        exit(1)
    }

case "generate":
    var options = parseOptions(optionArguments)
    autoDetect(into: &options)
    guard let config = makeConfiguration(options) else { exit(1) }
    persistProjectMetadata(options, output: config.outputDirectory)

    let engine = SpockGenEngine(config: config)
    runGenerate(engine: engine)
    syncXcodeProject(options, config: config)

    if options.watch {
        print("👀 SpockGen: Modo observación activo (--watch).")
        print("💡 Guarda en Xcode (⌘S) y los stubs se regenerarán al vuelo.")
        let watcher = FileWatcher(directories: config.sourcesDirectories + config.testsDirectories) {
            runGenerate(engine: engine)
        }
        watcher.start()
        RunLoop.main.run()
    }
    exit(0)

default:
    print("❌ Comando desconocido: '\(command)'. Usa generate, check, clean o daemon.")
    printUsage()
    exit(1)
}
