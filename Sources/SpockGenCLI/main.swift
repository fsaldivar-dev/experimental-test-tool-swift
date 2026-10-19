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

func printUsage() {
    print("""
    Uso: spock-gen [subcomando] [opciones]

    Subcomandos:
      daemon start   Inicia el demonio de observación en segundo plano
      daemon stop    Detiene el demonio en segundo plano
      daemon status  Muestra el estado del demonio (PID y logs)
      clean          Limpia el archivo de caché (.spock-cache.json) y resetea los stubs

    Opciones:
      --sources   <dir...>     Directorios de modelos de producción (Sources/)
      --tests     <dir...>     Directorios de tests con declaraciones @Stub (Tests/)
      --output    <ruta>       Ruta del archivo Swift generado (ej. Stubs.generated.swift)
      --cache     <ruta>       Ruta del archivo de caché (por defecto .spock-cache.json)
      --watch, -w              Modo reactivo: observa cambios al guardar (⌘S) y regenera al vuelo
      --verbose                Imprime información detallada del proceso
      --help, -h               Muestra esta ayuda

    Ejemplos:
      spock-gen --sources Example/Example/Domain --tests Example/ExampleTests --output Example/ExampleTests/Stubs.generated.swift
      spock-gen daemon start --sources Example/Example/Domain --tests Example/ExampleTests --output Example/ExampleTests/Stubs.generated.swift
      spock-gen daemon status
      spock-gen daemon stop
      spock-gen clean
    """)
}

func autoDetectConfig() -> (sources: [String], tests: [String], output: String)? {
    let fm = FileManager.default
    var foundSources: [String] = []
    var foundTests: [String] = []
    var foundOutput: String?

    if fm.fileExists(atPath: "Example/Example/Domain") {
        foundSources.append("Example/Example/Domain")
    } else if fm.fileExists(atPath: "Example/Sources") {
        foundSources.append("Example/Sources")
    } else if fm.fileExists(atPath: "Sources") {
        foundSources.append("Sources")
    }

    if fm.fileExists(atPath: "Example/ExampleTests") {
        foundTests.append("Example/ExampleTests")
        foundOutput = "Example/ExampleTests/Stubs.generated.swift"
    } else if fm.fileExists(atPath: "Tests") {
        foundTests.append("Tests")
        foundOutput = "Tests/Stubs.generated.swift"
    }

    if !foundSources.isEmpty && !foundTests.isEmpty, let out = foundOutput {
        return (foundSources, foundTests, out)
    }
    return nil
}

let args = Array(CommandLine.arguments.dropFirst())

if args.contains("-h") || args.contains("--help") {
    printUsage()
    exit(0)
}

// 1. Manejo de Subcomandos
if args.first == "daemon" {
    let sub = args.count > 1 ? args[1] : "status"
    let daemon = DaemonManager()

    switch sub {
    case "status":
        let st = daemon.status()
        if st.isRunning, let pid = st.pid {
            print("🟢 SpockGen Daemon está ACTIVO (PID: \(pid)).")
            print("📝 Archivo de log: \(st.logFilePath ?? ".spock-daemon.log")")
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
        let currentStatus = daemon.status()
        if currentStatus.isRunning, let pid = currentStatus.pid {
            print("⚠️ SpockGen Daemon ya está activo con PID \(pid).")
            exit(0)
        }

        // Parsear flags adicionales tras `daemon start`
        var dSources: [String] = []
        var dTests: [String] = []
        var dOutput: String?
        var dCache: String? = ".spock-cache.json"
        var dVerbose: Bool = false

        var curFlag: String? = nil
        for arg in args.dropFirst(2) {
            switch arg {
            case "--sources": curFlag = "--sources"
            case "--tests": curFlag = "--tests"
            case "--output": curFlag = "--output"
            case "--cache": curFlag = "--cache"
            case "--verbose": dVerbose = true; curFlag = nil
            default:
                if let flag = curFlag {
                    switch flag {
                    case "--sources": dSources.append(arg)
                    case "--tests": dTests.append(arg)
                    case "--output": dOutput = arg; curFlag = nil
                    case "--cache": dCache = arg; curFlag = nil
                    default: break
                    }
                }
            }
        }

        // Si faltan argumentos, intentar autodetectar
        if dSources.isEmpty || dTests.isEmpty || dOutput == nil {
            if let detected = autoDetectConfig() {
                if dSources.isEmpty { dSources = detected.sources }
                if dTests.isEmpty { dTests = detected.tests }
                if dOutput == nil { dOutput = detected.output }
            }
        }

        guard !dSources.isEmpty, !dTests.isEmpty, let finalOut = dOutput else {
            print("❌ Error: Especifica --sources, --tests y --output para iniciar el demonio.")
            exit(1)
        }

        let executablePath = CommandLine.arguments[0]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)

        var passArgs: [String] = ["--sources"] + dSources + ["--tests"] + dTests + ["--output", finalOut, "--watch"]
        if let cache = dCache { passArgs += ["--cache", cache] }
        if dVerbose { passArgs.append("--verbose") }
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
            for s in dSources { print("   - [Sources] \(s)") }
            for t in dTests { print("   - [Tests]   \(t)") }
            print("📁 Salida: \(finalOut)")
            print("📝 Log:    \(daemon.logFilePath)")
            print("💡 Los stubs se regenerarán automáticamente al presionar ⌘S en Xcode.")
            exit(0)
        } catch {
            print("❌ Error al iniciar el demonio: \(error.localizedDescription)")
            exit(1)
        }

    default:
        print("❌ Subcomando desconocido: '\(sub)'. Usa 'start', 'stop' o 'status'.")
        exit(1)
    }
}

if args.first == "clean" {
    var cOutput: String? = nil
    var cCache: String? = ".spock-cache.json"

    var curFlag: String? = nil
    for arg in args.dropFirst() {
        switch arg {
        case "--output": curFlag = "--output"
        case "--cache": curFlag = "--cache"
        default:
            if let flag = curFlag {
                switch flag {
                case "--output": cOutput = arg; curFlag = nil
                case "--cache": cCache = arg; curFlag = nil
                default: break
                }
            }
        }
    }

    if cOutput == nil, let detected = autoDetectConfig() {
        cOutput = detected.output
    }

    let fm = FileManager.default
    if let cachePath = cCache, fm.fileExists(atPath: cachePath) {
        try? fm.removeItem(atPath: cachePath)
        print("🧹 Archivo de caché (\(cachePath)) eliminado.")
    }

    if let out = cOutput {
        let cleanPlaceholder = """
        //
        //  Stubs.generated.swift
        //  SpockSwift 2 - Prebuild Generated Stubs
        //
        //  Generated automatically by spock-gen clean.
        //  No active @Stub declarations found.
        //

        import Foundation

        """
        try? cleanPlaceholder.write(toFile: out, atomically: true, encoding: .utf8)
        print("🧹 Archivo de stubs (\(out)) reseteado a estado limpio.")
    }

    print("✅ SpockGen limpiado exitosamente.")
    exit(0)
}

// 2. Ejecución normal o reactiva con flags
var sources: [String] = []
var tests: [String] = []
var output: String?
var cache: String? = ".spock-cache.json"
var verbose: Bool = false
var watchMode: Bool = false

var currentFlag: String? = nil
for arg in args {
    switch arg {
    case "--sources":
        currentFlag = "--sources"
    case "--tests":
        currentFlag = "--tests"
    case "--output":
        currentFlag = "--output"
    case "--cache":
        currentFlag = "--cache"
    case "--verbose":
        verbose = true
        currentFlag = nil
    case "--watch", "-w":
        watchMode = true
        currentFlag = nil
    default:
        if let flag = currentFlag {
            switch flag {
            case "--sources":
                sources.append(arg)
            case "--tests":
                tests.append(arg)
            case "--output":
                output = arg
                currentFlag = nil
            case "--cache":
                cache = arg
                currentFlag = nil
            default:
                break
            }
        }
    }
}

// Autodetección si faltan flags
if sources.isEmpty || tests.isEmpty || output == nil {
    if let detected = autoDetectConfig() {
        if sources.isEmpty { sources = detected.sources }
        if tests.isEmpty { tests = detected.tests }
        if output == nil { output = detected.output }
    }
}

guard !sources.isEmpty else {
    print("❌ Error: Debes especificar al menos un directorio de fuentes con --sources.")
    exit(1)
}

guard !tests.isEmpty else {
    print("❌ Error: Debes especificar al menos un directorio de tests con --tests.")
    exit(1)
}

guard let outputPath = output else {
    print("❌ Error: Debes especificar la ruta del archivo de salida con --output.")
    exit(1)
}

let config = SpockGenEngine.Configuration(
    sourcesDirectories: sources,
    testsDirectories: tests,
    outputPath: outputPath,
    cachePath: cache,
    verbose: verbose
)

// Persistir metadata con rutas absolutas para comunicación in-process con la extensión de Xcode
let cwd = FileManager.default.currentDirectoryPath
let absOutput = (outputPath as NSString).isAbsolutePath ? outputPath : URL(fileURLWithPath: cwd).appendingPathComponent(outputPath).standardized.path
let absSources = sources.map { ($0 as NSString).isAbsolutePath ? $0 : URL(fileURLWithPath: cwd).appendingPathComponent($0).standardized.path }
let absTests = tests.map { ($0 as NSString).isAbsolutePath ? $0 : URL(fileURLWithPath: cwd).appendingPathComponent($0).standardized.path }

let projectMetadata: [String: Any] = [
    "projectRoot": cwd,
    "outputPath": absOutput,
    "sources": absSources,
    "tests": absTests,
    "timestamp": Date().timeIntervalSince1970
]
if let data = try? JSONSerialization.data(withJSONObject: projectMetadata, options: .prettyPrinted) {
    try? data.write(to: URL(fileURLWithPath: "/tmp/.spock_active_project.json"))
}

let engine = SpockGenEngine(config: config)

@Sendable
func executeRun() {
    do {
        let result = try engine.run()
        switch result {
        case .upToDate:
            if engine.config.verbose {
                print("⚡ SpockGen: Archivos actualizados (Caché hit).")
            }
        case .generated(let count, let path):
            print("✅ SpockGen: Se generaron stubs para \(count) modelos en: \(path)")
        case .noStubsFound:
            if engine.config.verbose {
                print("ℹ️ SpockGen: No se encontraron anotaciones @Stub activas.")
            }
        }
    } catch {
        print("❌ Error en SpockGen: \(error.localizedDescription)")
    }
}

// 1. Ejecución inicial del motor de generación
executeRun()

// 2. Garantizar como salvaguarda que el archivo existe en disco para que Xcode nunca falle
XcodeProjectIntegrator.ensureGeneratedFileExists(atPath: outputPath)

// 3. Auto-sincronización con el manifiesto project.pbxproj si existe proyecto Xcode
if let pbxPath = XcodeProjectIntegrator.findXcodeProject(nearPath: outputPath) {
    let fileName = (outputPath as NSString).lastPathComponent
    if let status = try? XcodeProjectIntegrator.integrate(
        projectPbxprojPath: pbxPath,
        generatedFileName: fileName,
        sourcesDir: sources.first ?? "",
        testsDir: tests.first ?? ""
    ), case .integrated = status {
        print("🛠️ SpockGen: \(fileName) y build phase sincronizados automáticamente con el manifiesto de Xcode.")
    }
}

// Si se activó modo watch
if watchMode {
    print("👀 SpockGen: Modo observación activo (--watch).")
    print("💡 Presiona ⌘S en Xcode al terminar de escribir: los stubs se generarán reactivamente.")
    let watcher = FileWatcher(directories: sources + tests) {
        executeRun()
    }
    watcher.start()
    RunLoop.main.run()
} else {
    exit(0)
}
