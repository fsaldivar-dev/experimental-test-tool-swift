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
                .nameKey: "Spock: Generate Stubs"
            ],
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.addStubToSelection",
                .nameKey: "Spock: Add @Stub to Selection"
            ],
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.cleanStubs",
                .nameKey: "Spock: Clean Stubs"
            ],
            [
                .classNameKey: SourceEditorCommand.className(),
                .identifierKey: "com.fsaldivar.SpockXcodeExtension.toggleDaemon",
                .nameKey: "Spock: Toggle Watch Daemon"
            ]
        ]
    }
}
