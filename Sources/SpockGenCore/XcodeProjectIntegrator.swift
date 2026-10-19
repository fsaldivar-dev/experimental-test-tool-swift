//
//  XcodeProjectIntegrator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation

/// Se encarga de verificar e integrar automáticamente `Stubs.generated.swift` y la fase de compilación
/// en el archivo `project.pbxproj` de Xcode, evitando errores de manifiesto faltante.
public struct XcodeProjectIntegrator: Sendable {
    public static let defaultFileRefId = "467F1FBD7E554847B5B76584"
    public static let defaultBuildFileId = "467F1FBD7E554847B5B76585"
    public static let defaultScriptPhaseId = "A1B2C3D4E5F6789012345678"

    public enum IntegrationStatus: Sendable, Equatable {
        case alreadyIntegrated
        case integrated(projectPath: String)
        case noProjectFound
    }

    public static func ensureGeneratedFileExists(atPath outputPath: String) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: outputPath) {
            let parentDir = URL(fileURLWithPath: outputPath).deletingLastPathComponent()
            try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            let placeholder = """
            //
            //  Stubs.generated.swift
            //  SpockSwift 2 - Prebuild Generated Stubs
            //
            //  Generated automatically by spock-gen.
            //

            import Foundation

            """
            try? placeholder.write(toFile: outputPath, atomically: true, encoding: .utf8)
        }
    }

    public static func findXcodeProject(nearPath path: String) -> String? {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path).standardized

        for _ in 0..<5 {
            if let items = try? fileManager.contentsOfDirectory(atPath: currentURL.path) {
                // 1. Si hay un .xcworkspace, resolver los .xcodeproj declarados en contents.xcworkspacedata
                for item in items where item.hasSuffix(".xcworkspace") {
                    let workspaceURL = currentURL.appendingPathComponent(item)
                    let dataURL = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
                    if let xml = try? String(contentsOf: dataURL, encoding: .utf8) {
                        for line in xml.components(separatedBy: .newlines) {
                            if line.contains(".xcodeproj") {
                                let parts = line.components(separatedBy: "\"")
                                for part in parts where part.contains(".xcodeproj") {
                                    let cleaned = part.replacingOccurrences(of: "group:", with: "")
                                                      .replacingOccurrences(of: "container:", with: "")
                                    let resolvedProjURL = currentURL.appendingPathComponent(cleaned).appendingPathComponent("project.pbxproj")
                                    if fileManager.fileExists(atPath: resolvedProjURL.path) {
                                        return resolvedProjURL.path
                                    }
                                }
                            }
                        }
                    }
                }

                // 2. Búsqueda directa de .xcodeproj
                for item in items where item.hasSuffix(".xcodeproj") {
                    let pbxPath = currentURL.appendingPathComponent(item).appendingPathComponent("project.pbxproj").path
                    if fileManager.fileExists(atPath: pbxPath) {
                        return pbxPath
                    }
                }
            }
            let parent = currentURL.deletingLastPathComponent()
            if parent.path == currentURL.path { break }
            currentURL = parent
        }
        return nil
    }

    @discardableResult
    public static func integrate(
        projectPbxprojPath: String,
        generatedFileName: String = "Stubs.generated.swift",
        sourcesDir: String,
        testsDir: String
    ) throws -> IntegrationStatus {
        let pbxURL = URL(fileURLWithPath: projectPbxprojPath)
        guard let originalContent = try? String(contentsOf: pbxURL, encoding: .utf8) else {
            return .noProjectFound
        }

        var content = originalContent
        var modified = false

        // 1. Verificar si Stubs.generated.swift ya está referenciado
        if !content.contains(generatedFileName) {
            // Inyectar PBXBuildFile
            let buildFile = "\t\t\(defaultBuildFileId) /* \(generatedFileName) in Sources */ = {isa = PBXBuildFile; fileRef = \(defaultFileRefId) /* \(generatedFileName) */; };\n"
            content = content.replaceOnce(target: "/* Begin PBXBuildFile section */\n", replacement: "/* Begin PBXBuildFile section */\n" + buildFile)

            // Inyectar PBXFileReference
            let fileRef = "\t\t\(defaultFileRefId) /* \(generatedFileName) */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \(generatedFileName); sourceTree = \"<group>\"; };\n"
            content = content.replaceOnce(target: "/* Begin PBXFileReference section */\n", replacement: "/* Begin PBXFileReference section */\n" + fileRef)

            // Inyectar en PBXGroup de Tests
            if let groupRange = content.range(of: "path = ExampleTests;\n\t\t\tsourceTree = \"<group>\";") ?? content.range(of: "path = Tests;\n\t\t\tsourceTree = \"<group>\";") {
                let prefix = content[..<groupRange.lowerBound]
                if let lastParen = prefix.range(of: ");", options: .backwards) {
                    let insertion = "\t\t\t\t\(defaultFileRefId) /* \(generatedFileName) */,\n\t\t\t"
                    content.insert(contentsOf: insertion, at: lastParen.lowerBound)
                }
            }

            // Inyectar en PBXSourcesBuildPhase de Tests
            if let sourcesRange = content.range(of: "BD6A96DAEC2042729D26303D /* UserServiceMockTests.swift in Sources */,\n") {
                let insertion = "\t\t\t\t\(defaultBuildFileId) /* \(generatedFileName) in Sources */,\n"
                content.insert(contentsOf: insertion, at: sourcesRange.upperBound)
            }

            modified = true
        }

        // 2. Verificar si el Run Script Phase ya está presente
        if !content.contains("Generate Spock Stubs") && !content.contains("spock-gen") {
            let scriptPhaseSection = """
            /* Begin PBXShellScriptBuildPhase section */
            \t\t\(defaultScriptPhaseId) /* Generate Spock Stubs */ = {
            \t\t\tisa = PBXShellScriptBuildPhase;
            \t\t\talwaysOutOfDate = 1;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t);
            \t\t\tinputFileListPaths = (
            \t\t\t);
            \t\t\tinputPaths = (
            \t\t\t\t"$(SRCROOT)/Example/Domain",
            \t\t\t\t"$(SRCROOT)/ExampleTests",
            \t\t\t);
            \t\t\tname = "Generate Spock Stubs";
            \t\t\toutputFileListPaths = (
            \t\t\t);
            \t\t\toutputPaths = (
            \t\t\t\t"$(SRCROOT)/ExampleTests/Stubs.generated.swift",
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t\tshellPath = /bin/sh;
            \t\t\tshellScript = "unset SDKROOT\\nunset PLATFORM_NAME\\ncd \\"${SRCROOT}/..\\"\\nswift run spock-gen --sources \\"${SRCROOT}/Example/Domain\\" --tests \\"${SRCROOT}/ExampleTests\\" --output \\"${SRCROOT}/ExampleTests/Stubs.generated.swift\\" --cache \\"${DERIVED_FILE_DIR}/.spock-cache.json\\"\\n";
            \t\t\tshowEnvVarsInLog = 0;
            \t\t};
            /* End PBXShellScriptBuildPhase section */\n\n
            """
            content = content.replaceOnce(target: "/* Begin PBXSourcesBuildPhase section */\n", replacement: scriptPhaseSection + "/* Begin PBXSourcesBuildPhase section */\n")

            // Inyectar en buildPhases de ExampleTests antes de Sources
            let targetPhases = "buildPhases = (\n\t\t\t\tC57424A1588A47138ED504B3 /* Sources */,"
            let targetPhasesReplacement = "buildPhases = (\n\t\t\t\t\(defaultScriptPhaseId) /* Generate Spock Stubs */,\n\t\t\t\tC57424A1588A47138ED504B3 /* Sources */,"
            content = content.replaceOnce(target: targetPhases, replacement: targetPhasesReplacement)

            modified = true
        }

        if modified {
            try content.write(to: pbxURL, atomically: true, encoding: .utf8)
            return .integrated(projectPath: projectPbxprojPath)
        } else {
            return .alreadyIntegrated
        }
    }
}

private extension String {
    func replaceOnce(target: String, replacement: String) -> String {
        if let range = self.range(of: target) {
            return self.replacingCharacters(in: range, with: replacement)
        }
        return self
    }
}
