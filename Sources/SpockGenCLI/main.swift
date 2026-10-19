//
//  main.swift
//  spock-gen CLI
//
//  Created for SpockSwift 2.
//

import Foundation
import SpockGenCore

func printUsage() {
    print("""
    Uso: spock-gen --sources <dir1> [dir2...] --tests <testDir1> [testDir2...] --output <output.swift> [--cache <cache.json>] [--watch] [--verbose]

    Opciones:
      --sources   Uno o más directorios de modelos de producción (Sources/)
      --tests     Uno o más directorios de tests con declaraciones @Stub (Tests/)
      --output    Ruta del archivo Swift generado (ej. Stubs.generated.swift)
      --cache     Ruta del archivo de caché (por defecto .spock-cache.json)
      --watch, -w Modo reactivo: observa cambios al guardar (⌘S) y regenera al detectar sintaxis válida
      --verbose   Imprime información detallada del proceso
      --help, -h  Muestra esta ayuda
    """)
}

var sources: [String] = []
var tests: [String] = []
var output: String?
var cache: String? = ".spock-cache.json"
var verbose: Bool = false
var watchMode: Bool = false

var currentFlag: String? = nil
let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty || args.contains("-h") || args.contains("--help") {
    printUsage()
    exit(0)
}

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

// 1. Garantizar que el archivo existe en disco para que Xcode nunca falle por archivo inexistente
XcodeProjectIntegrator.ensureGeneratedFileExists(atPath: outputPath)

// 2. Auto-sincronización con el manifiesto project.pbxproj si existe proyecto Xcode
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

let config = SpockGenEngine.Configuration(
    sourcesDirectories: sources,
    testsDirectories: tests,
    outputPath: outputPath,
    cachePath: cache,
    verbose: verbose
)

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
                print("ℹ️ SpockGen: No se encontraron anotaciones @Stub.")
            }
        }
    } catch {
        print("❌ Error en SpockGen: \(error.localizedDescription)")
    }
}

// Ejecución inicial
executeRun()

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
