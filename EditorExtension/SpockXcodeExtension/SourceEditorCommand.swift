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
        let stubSnippet = "\n@Stub\nextension \(typeName) {}\n"

        let insertIndex = min(endLine + 1, lines.count)
        lines.insert(stubSnippet, at: insertIndex)

        // Regenerar stubs in-process
        _ = runEngineInProcess()
    }

    private func handleGenerateStubs(invocation: XCSourceEditorCommandInvocation) throws {
        // Ejecutar motor de generación in-process
        if let generated = runEngineInProcess() {
            if isStubsGeneratedBuffer(invocation.buffer) {
                invocation.buffer.completeBuffer = generated
            }
        } else if let diskContent = readDiskGeneratedStubs() {
            if isStubsGeneratedBuffer(invocation.buffer) {
                invocation.buffer.completeBuffer = diskContent
            }
        }
    }

    private func handleCleanStubs(invocation: XCSourceEditorCommandInvocation) throws {
        let buffer = invocation.buffer
        let isStubsBuffer = isStubsGeneratedBuffer(buffer)

        if isStubsBuffer {
            let lines = buffer.lines
            var cleanedSpecificBlock = false

            // 1. Si el cursor o selección está en o dentro de un bloque 'extension Model { ... }'
            if let selections = buffer.selections as? [XCSourceTextRange], let selection = selections.first {
                let currentLine = selection.start.line
                if currentLine < lines.count, let range = findExtensionBlock(around: currentLine, in: lines) {
                    for idx in stride(from: range.upperBound, through: range.lowerBound, by: -1) {
                        if idx < lines.count {
                            lines.removeObject(at: idx)
                        }
                    }
                    cleanedSpecificBlock = true
                    syncToDiskIfPossible(content: buffer.completeBuffer)
                }
            }

            if cleanedSpecificBlock {
                return
            }

            // 2. Si no hay bloque específico seleccionado, intentar recargar desde el motor o disco
            // donde los stubs ya fueron limpiados de modelos huérfanos
            if let generated = runEngineInProcess() {
                buffer.completeBuffer = generated
                return
            }

            if let diskContent = readDiskGeneratedStubs(), !diskContent.isEmpty {
                buffer.completeBuffer = diskContent
                return
            }

            // 3. Fallback: resetear buffer a estado limpio
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
            return
        }

        // Si el archivo es un archivo de tests (ej. UserStubTests.swift)
        // Eliminar las anotaciones @Stub seleccionadas
        if let selections = buffer.selections as? [XCSourceTextRange], let selection = selections.first {
            let startLine = selection.start.line
            let endLine = selection.end.line
            let lines = buffer.lines

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

            // Tras remover la anotación, regenerar stubs en segundo plano para purgar
            _ = runEngineInProcess()
        }
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

    private func findExtensionBlock(around lineIndex: Int, in lines: NSMutableArray) -> ClosedRange<Int>? {
        guard lineIndex >= 0 && lineIndex < lines.count else { return nil }

        // Buscar el inicio de 'extension ' hacia arriba
        var start = lineIndex
        while start >= 0 {
            let line = (lines[start] as? String ?? "").trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("extension ") || line.contains(" extension ") {
                break
            }
            if lineIndex - start > 60 {
                return nil
            }
            start -= 1
        }
        guard start >= 0 else { return nil }

        // Desde 'start', buscar el cierre de llaves '{' ... '}'
        var openBraces = 0
        var foundOpening = false
        var end = start

        while end < lines.count {
            let line = lines[end] as? String ?? ""
            for char in line {
                if char == "{" {
                    openBraces += 1
                    foundOpening = true
                } else if char == "}" {
                    openBraces -= 1
                }
            }
            if foundOpening && openBraces <= 0 {
                break
            }
            end += 1
        }

        guard foundOpening && openBraces <= 0 && end < lines.count else { return nil }

        // Incluir una línea vacía posterior si existe
        if end + 1 < lines.count {
            let nextLine = (lines[end + 1] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if nextLine.isEmpty {
                end += 1
            }
        }

        return start...end
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
        let fallbackSrc = ["\(candidateProjectRoot)/Example/Example/Domain"]
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
