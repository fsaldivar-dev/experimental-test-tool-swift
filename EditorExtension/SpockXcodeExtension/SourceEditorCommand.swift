//
//  SourceEditorCommand.swift
//  SpockXcodeExtension
//
//  Created for SpockSwift 2.
//

import Foundation
import XcodeKit
import SpockGenCore

enum SpockExtensionError: LocalizedError {
    case unsupportedContentType
    case unknownCommand(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedContentType:
            return "Spock solo soporta archivos fuente de Swift."
        case .unknownCommand(let id):
            return "Comando de Spock desconocido: \(id)"
        }
    }
}

final class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation) async throws {
        guard invocation.buffer.contentUTI == "public.swift-source" else {
            throw SpockExtensionError.unsupportedContentType
        }

        let commandId = invocation.commandIdentifier

        if commandId.hasSuffix("addStubToSelection") {
            try handleAddStubToSelection(invocation: invocation)
        } else if commandId.hasSuffix("generateStubs") {
            try handleGenerateStubs(invocation: invocation)
        } else if commandId.hasSuffix("cleanStubs") {
            try handleCleanStubs(invocation: invocation)
        } else if commandId.hasSuffix("toggleDaemon") {
            try handleToggleDaemon(invocation: invocation)
        } else {
            throw SpockExtensionError.unknownCommand(commandId)
        }
    }

    // MARK: - Handlers

    private func handleAddStubToSelection(invocation: XCSourceEditorCommandInvocation) throws {
        let buffer = invocation.buffer
        guard let selections = buffer.selections as? [XCSourceTextRange], let selection = selections.first else {
            return
        }

        let startLine = selection.start.line
        let endLine = selection.end.line
        let lines = buffer.lines

        guard startLine < lines.count else { return }

        var selectedText = ""
        if startLine == endLine {
            let line = lines[startLine] as? String ?? ""
            let startCol = min(selection.start.column, line.count)
            let endCol = min(selection.end.column, line.count)
            if startCol < endCol {
                let startIndex = line.index(line.startIndex, offsetBy: startCol)
                let endIndex = line.index(line.startIndex, offsetBy: endCol)
                selectedText = String(line[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("struct ") || trimmed.contains("class ") {
                    let parts = trimmed.components(separatedBy: " ")
                    if let kwIndex = parts.firstIndex(where: { $0 == "struct" || $0 == "class" }), kwIndex + 1 < parts.count {
                        selectedText = parts[kwIndex + 1].trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    }
                }
            }
        }

        let typeName = selectedText.isEmpty ? "Model" : selectedText

        // Si el modelo seleccionado vive en este mismo archivo, generar su stub completo inmediatamente
        let models = ModelParser.parse(source: buffer.completeBuffer)
        if let matchedModel = models.first(where: { $0.name == typeName }) {
            let generator = CodeGenerator()
            let fullExtension = generator.generate(models: [matchedModel], availableModels: [matchedModel.name: matchedModel])
            if let extStart = fullExtension.range(of: "extension \(matchedModel.name)") {
                let stubSnippet = "\n@Stub\n" + String(fullExtension[extStart.lowerBound...]) + "\n"
                let insertIndex = min(endLine + 1, lines.count)
                lines.insert(stubSnippet, at: insertIndex)
                _ = runEngineInProcess()
                return
            }
        }

        let stubSnippet = "\n@Stub\nextension \(typeName) {}\n"
        let insertIndex = min(endLine + 1, lines.count)
        lines.insert(stubSnippet, at: insertIndex)

        // Regenerar stubs in-process
        _ = runEngineInProcess()
    }

    private func handleGenerateStubs(invocation: XCSourceEditorCommandInvocation) throws {
        let buffer = invocation.buffer

        if let config = resolveConfiguration() {
            saveActiveBufferIfKnown(buffer: buffer, config: config)
        }

        // 1. Ejecutar motor de generación in-process para el proyecto
        if let generated = runEngineInProcess() {
            if isStubsGeneratedBuffer(buffer) {
                buffer.completeBuffer = generated
            }
        } else if let diskContent = readDiskGeneratedStubs() {
            if isStubsGeneratedBuffer(buffer) {
                buffer.completeBuffer = diskContent
            }
        }
    }

    private func handleCleanStubs(invocation: XCSourceEditorCommandInvocation) throws {
        let buffer = invocation.buffer
        let isStubsBuffer = isStubsGeneratedBuffer(buffer)

        if let config = resolveConfiguration() {
            saveActiveBufferIfKnown(buffer: buffer, config: config)
        }

        // 1. Si el usuario está viendo Stubs.generated.swift en el editor:
        if isStubsBuffer {
            if let generated = runEngineInProcess() {
                buffer.completeBuffer = generated
                syncToDiskIfPossible(content: generated)
            } else if let diskContent = readDiskGeneratedStubs(), !diskContent.isEmpty {
                buffer.completeBuffer = diskContent
            } else {
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
                buffer.completeBuffer = cleanPlaceholder
                syncToDiskIfPossible(content: cleanPlaceholder)
            }
            return
        }

        // 2. Si el usuario está en un archivo de test (ej. UserStubTests.swift)
        let lines = buffer.lines

        // A) Si hay selección específica, remover cualquier anotación @Stub o extension dentro de la selección
        if let selections = buffer.selections as? [XCSourceTextRange], let selection = selections.first {
            let startLine = selection.start.line
            let endLine = selection.end.line
            if startLine != endLine || selection.start.column != selection.end.column {
                var toRemove = [Int]()
                let searchStart = max(0, startLine - 1)
                let searchEnd = min(lines.count - 1, endLine + 1)
                for idx in searchStart...searchEnd {
                    let lineStr = lines[idx] as? String ?? ""
                    if lineStr.contains("@Stub") || lineStr.contains("extension ") {
                        toRemove.append(idx)
                    }
                }
                for idx in toRemove.sorted(by: >) {
                    lines.removeObject(at: idx)
                }
            }
        }

        // B) Limpiar declaraciones @Stub de modelos eliminados (huérfanos) en el archivo actual
        cleanOrphanedStubsInTestBuffer(buffer: buffer)

        // C) Guardar cambios en disco y ejecutar motor para actualizar Stubs.generated.swift
        if let config = resolveConfiguration() {
            saveActiveBufferIfKnown(buffer: buffer, config: config)
        }
        _ = runEngineInProcess()
    }

    private func handleToggleDaemon(invocation: XCSourceEditorCommandInvocation) throws {
        let daemon = DaemonManager()
        if daemon.status().isRunning {
            daemon.stop()
        }
    }

    // MARK: - Helpers

    private func isStubsGeneratedBuffer(_ buffer: XCSourceTextBuffer) -> Bool {
        let text = buffer.completeBuffer
        return text.contains("Stubs.generated.swift") || text.contains("SpockSwift 2 - Prebuild Generated Stubs")
    }

    private func saveActiveBufferIfKnown(buffer: XCSourceTextBuffer, config: SpockGenEngine.Configuration) {
        if isStubsGeneratedBuffer(buffer) { return }
        let text = buffer.completeBuffer

        // 1. Buscar nombre de archivo en los comentarios iniciales: "//  UserStubTests.swift"
        let lines = text.components(separatedBy: .newlines).prefix(10)
        var fileName: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") && trimmed.contains(".swift") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if let match = parts.first(where: { $0.hasSuffix(".swift") }) {
                    fileName = match
                    break
                }
            }
        }

        let allDirs = config.sourcesDirectories + config.testsDirectories
        let fm = FileManager.default

        if let targetName = fileName {
            for dir in allDirs {
                let candidate = (dir as NSString).appendingPathComponent(targetName)
                if fm.fileExists(atPath: candidate) {
                    try? text.write(toFile: candidate, atomically: true, encoding: .utf8)
                    return
                }
                if let enumerator = fm.enumerator(atPath: dir) {
                    while let relPath = enumerator.nextObject() as? String {
                        if relPath.hasSuffix(targetName) {
                            let full = (dir as NSString).appendingPathComponent(relPath)
                            try? text.write(toFile: full, atomically: true, encoding: .utf8)
                            return
                        }
                    }
                }
            }
        }
    }

    private func cleanOrphanedStubsInTestBuffer(buffer: XCSourceTextBuffer) {
        guard let config = resolveConfiguration() else { return }

        // Recolectar todos los nombres de modelos válidos en el proyecto
        var availableModelNames = Set<String>()
        let fm = FileManager.default
        let allDirs = config.sourcesDirectories + config.testsDirectories

        for dir in allDirs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir, isDirectory: &isDir) {
                if !isDir.boolValue && dir.hasSuffix(".swift") {
                    if let content = try? String(contentsOfFile: dir, encoding: .utf8) {
                        for m in ModelParser.parse(source: content, filePath: dir) {
                            availableModelNames.insert(m.name)
                        }
                    }
                    continue
                }

                if let enumerator = fm.enumerator(atPath: dir) {
                    while let relPath = enumerator.nextObject() as? String {
                        if relPath.hasSuffix(".swift") && !relPath.hasSuffix(".generated.swift") {
                            let fullPath = (dir as NSString).appendingPathComponent(relPath)
                            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                                for m in ModelParser.parse(source: content, filePath: fullPath) {
                                    availableModelNames.insert(m.name)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Incluir modelos definidos en el buffer actual
        for m in ModelParser.parse(source: buffer.completeBuffer) {
            availableModelNames.insert(m.name)
        }

        // Buscar anotaciones @Stub y extensiones de modelos que ya no existen
        let lines = buffer.lines
        var indicesToRemove = [Int]()

        var i = 0
        while i < lines.count {
            let line = (lines[i] as? String ?? "").trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("@Stub") {
                var targetType: String?
                var extEndLine = i
                for j in (i + 1)..<min(i + 5, lines.count) {
                    let nextLine = (lines[j] as? String ?? "").trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("extension ") {
                        let parts = nextLine.components(separatedBy: " ")
                        if parts.count >= 2 {
                            let rawName = parts[1].trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                            targetType = rawName
                            extEndLine = j
                            if nextLine.contains("}") {
                                break
                            }
                            // Buscar cierre de llave '}'
                            for k in (j + 1)..<min(j + 5, lines.count) {
                                let closeLine = (lines[k] as? String ?? "").trimmingCharacters(in: .whitespaces)
                                if closeLine.contains("}") {
                                    extEndLine = k
                                    break
                                }
                            }
                            break
                        }
                    }
                }

                if let type = targetType, !availableModelNames.contains(type) {
                    for k in i...extEndLine {
                        indicesToRemove.append(k)
                    }
                    i = extEndLine + 1
                    continue
                }
            }
            i += 1
        }

        for idx in Set(indicesToRemove).sorted(by: >) {
            if idx < lines.count {
                lines.removeObject(at: idx)
            }
        }
    }

    private func resolveConfiguration() -> SpockGenEngine.Configuration? {
        let fm = FileManager.default

        // 1. Intentar leer metadata de /tmp/.spock_active_project.json
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/.spock_active_project.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let out = json["outputPath"] as? String,
           let src = json["sources"] as? [String],
           let tst = json["tests"] as? [String] {
            return SpockGenEngine.Configuration(
                sourcesDirectories: src,
                testsDirectories: tst,
                outputPath: out,
                cachePath: nil,
                verbose: false
            )
        }

        // 2. Fallback estándar al proyecto Example conocido
        let home = fm.homeDirectoryForCurrentUser.path
        let candidateProjectRoot = "\(home)/Documents/experimental-test-tool-swift"
        let fallbackOut = "\(candidateProjectRoot)/Example/ExampleTests/Stubs.generated.swift"
        let fallbackSrc = ["\(candidateProjectRoot)/Example/Example"]
        let fallbackTst = ["\(candidateProjectRoot)/Example/ExampleTests"]

        if fm.fileExists(atPath: "\(candidateProjectRoot)/Example") {
            return SpockGenEngine.Configuration(
                sourcesDirectories: fallbackSrc,
                testsDirectories: fallbackTst,
                outputPath: fallbackOut,
                cachePath: nil,
                verbose: false
            )
        }

        return nil
    }

    @discardableResult
    private func runEngineInProcess() -> String? {
        guard let config = resolveConfiguration() else { return nil }
        let engine = SpockGenEngine(config: config)
        do {
            let result = try engine.run()
            switch result {
            case .generated(_, let out):
                return try? String(contentsOfFile: out, encoding: .utf8)
            case .upToDate:
                return try? String(contentsOfFile: config.outputPath, encoding: .utf8)
            case .noStubsFound:
                return try? String(contentsOfFile: config.outputPath, encoding: .utf8)
            }
        } catch {
            return nil
        }
    }

    private func readDiskGeneratedStubs() -> String? {
        guard let config = resolveConfiguration() else { return nil }
        return try? String(contentsOfFile: config.outputPath, encoding: .utf8)
    }

    private func syncToDiskIfPossible(content: String) {
        guard let config = resolveConfiguration() else { return }
        try? content.write(toFile: config.outputPath, atomically: true, encoding: .utf8)
    }
}
