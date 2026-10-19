//
//  SourceEditorExtension.swift
//  SpockXcodeExtension
//
//  Created for SpockSwift 2.
//

import Foundation
import XcodeKit

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() {
        // Inicialización de la extensión de Spock para Xcode
    }

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        return [
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.generateStubs",
                .nameKey: "Generate Stubs"
            ],
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.addStubToSelection",
                .nameKey: "Add @Stub to Selection"
            ],
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.cleanStubs",
                .nameKey: "Clean Stubs"
            ],
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.toggleDaemon",
                .nameKey: "Toggle Watch Daemon"
            ]
        ]
    }
}
