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
                // Si no hay texto seleccionado pero el cursor está en una línea con struct/class
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

        // Insertar después de la selección o al final del archivo
        let insertIndex = min(endLine + 1, lines.count)
        lines.insert(stubSnippet, at: insertIndex)

        // Ejecutar regeneración tras agregar la anotación
        try? handleGenerateStubs(invocation: invocation)
    }

    private func handleGenerateStubs(invocation: XCSourceEditorCommandInvocation) throws {
        // Ejecutar pipeline a través de SpockGenEngine si hay proyecto detectable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "spock-gen"]
        try? process.run()
        process.waitUntilExit()

        // Si el archivo activo es Stubs.generated.swift, recargar el buffer directamente
        if let currentText = invocation.buffer.completeBuffer as String?,
           currentText.contains("Stubs.generated.swift") {
            if let reloaded = try? String(contentsOfFile: "Example/ExampleTests/Stubs.generated.swift", encoding: .utf8) {
                invocation.buffer.completeBuffer = reloaded
            }
        }
    }

    private func handleCleanStubs(invocation: XCSourceEditorCommandInvocation) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "spock-gen", "clean"]
        try? process.run()
        process.waitUntilExit()
    }

    private func handleToggleDaemon(invocation: XCSourceEditorCommandInvocation) throws {
        let daemon = DaemonManager()
        if daemon.status().isRunning {
            daemon.stop()
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["swift", "run", "spock-gen", "daemon", "start"]
            try? process.run()
        }
    }
}
