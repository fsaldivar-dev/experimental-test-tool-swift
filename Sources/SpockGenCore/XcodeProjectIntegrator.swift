//
//  XcodeProjectIntegrator.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import CryptoKit

/// Mantiene un proyecto de Xcode (`project.pbxproj`) sincronizado con la carpeta `Generated`.
///
/// Xcode decide qué archivos compila al cargar el proyecto, antes de ejecutar fases o pre-actions.
/// Para que borrar `Generated` y compilar una sola vez funcione, cada archivo generado debe estar
/// referenciado en el proyecto y declarado como output de una fase de script que lo regenere.
/// `sync` reconstruye ese árbol a partir de lo que hay en disco, de forma idempotente:
/// grupos que reflejan las carpetas, una referencia por archivo, y la fase de script.
///
/// Todo lo que escribe lleva identificadores con el prefijo `5B0C4E5F`, así puede retirarlo
/// limpiamente en la siguiente sincronización.
public struct XcodeProjectIntegrator: Sendable {
    /// Prefijo de los identificadores de objetos que gestiona spock-gen.
    public static let objectPrefix = "5B0C4E5F"
    public static let scriptPhaseName = "Spock: regenerar Generated si falta"

    public enum SyncStatus: Sendable, Equatable {
        /// El proyecto ya reflejaba la carpeta.
        case upToDate(filesCount: Int)
        /// Se reescribió el proyecto.
        case synchronized(filesCount: Int)
        case noProjectFound
        case targetNotFound(String)
        case parentGroupNotFound(String)
    }

    public struct SyncRequest: Sendable {
        public var projectPbxprojPath: String
        /// Nombre del target de tests que compila los archivos generados.
        public var targetName: String
        /// Carpeta `Generated` (relativa al directorio actual o absoluta).
        public var generatedDirectory: String
        /// Comando que regenera la carpeta, tal como debe ejecutarse desde la raíz del paquete.
        public var generateCommand: String

        public init(projectPbxprojPath: String, targetName: String, generatedDirectory: String, generateCommand: String) {
            self.projectPbxprojPath = projectPbxprojPath
            self.targetName = targetName
            self.generatedDirectory = generatedDirectory
            self.generateCommand = generateCommand
        }
    }

    // MARK: - Localización

    public static func findXcodeProject(nearPath path: String) -> String? {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path).standardized

        for _ in 0..<5 {
            if let items = try? fileManager.contentsOfDirectory(atPath: currentURL.path) {
                for item in items where item.hasSuffix(".xcworkspace") {
                    let dataURL = currentURL.appendingPathComponent(item).appendingPathComponent("contents.xcworkspacedata")
                    if let xml = try? String(contentsOf: dataURL, encoding: .utf8) {
                        for line in xml.components(separatedBy: .newlines) where line.contains(".xcodeproj") {
                            for part in line.components(separatedBy: "\"") where part.contains(".xcodeproj") {
                                let cleaned = part.replacingOccurrences(of: "group:", with: "")
                                    .replacingOccurrences(of: "container:", with: "")
                                let resolved = currentURL.appendingPathComponent(cleaned).appendingPathComponent("project.pbxproj")
                                if fileManager.fileExists(atPath: resolved.path) {
                                    return resolved.path
                                }
                            }
                        }
                    }
                }
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

    /// Crea un archivo placeholder si no existe (formato legado de archivo único).
    public static func ensureGeneratedFileExists(atPath outputPath: String) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: outputPath) else { return }
        try? fileManager.createDirectory(at: URL(fileURLWithPath: outputPath).deletingLastPathComponent(), withIntermediateDirectories: true)
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

    // MARK: - Sincronización

    @discardableResult
    public static func sync(_ request: SyncRequest) throws -> SyncStatus {
        let pbxURL = URL(fileURLWithPath: request.projectPbxprojPath)
        guard let original = try? String(contentsOf: pbxURL, encoding: .utf8) else {
            return .noProjectFound
        }

        // Rutas: SRCROOT es la carpeta que contiene el .xcodeproj
        let projectDirectory = pbxURL.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL
        let generatedURL = URL(fileURLWithPath: request.generatedDirectory).standardizedFileURL
        let generatedRelative = relativePath(from: projectDirectory, to: generatedURL)   // "ExampleTests/Generated"
        let packageRelative = relativePath(from: projectDirectory, to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL) // ".."
        let generatedFolderName = generatedURL.lastPathComponent
        let parentFolderName = generatedURL.deletingLastPathComponent().lastPathComponent

        var content = removeManagedObjects(from: original)

        // Archivos en disco
        let files = generatedSwiftFiles(in: generatedURL)   // relativos a Generated, ordenados

        // Target y sus fases
        guard let target = nativeTargetBlock(named: request.targetName, in: content) else {
            return .targetNotFound(request.targetName)
        }
        guard let sourcesPhaseId = firstMatch(#"(\w{24}) /\* Sources \*/,"#, in: target) else {
            return .targetNotFound(request.targetName)
        }

        // Grupo padre: el PBXGroup cuyo path es la carpeta que contiene Generated (o el mainGroup)
        guard let parentGroupId = groupId(withPath: parentFolderName, in: content) ?? mainGroupId(in: content) else {
            return .parentGroupNotFound(parentFolderName)
        }

        // Construir objetos
        var buildFiles: [String] = []
        var fileRefs: [String] = []
        var groups: [String: (name: String, path: String, children: [String])] = [:]   // id -> group
        var groupOrder: [String] = []
        var sourcesEntries: [String] = []
        var outputPaths: [String] = []

        func ensureGroup(_ relativeDir: String) -> String {
            let id = objectId("group:" + relativeDir)
            if groups[id] == nil {
                let name = relativeDir.isEmpty ? generatedFolderName : (relativeDir as NSString).lastPathComponent
                let path = relativeDir.isEmpty ? generatedFolderName : name
                groups[id] = (name: name, path: path, children: [])
                groupOrder.append(id)
                if !relativeDir.isEmpty {
                    let parentDir = (relativeDir as NSString).deletingLastPathComponent
                    let parentId = ensureGroup(parentDir)
                    groups[parentId]!.children.append("\(id) /* \(name) */")
                }
            }
            return id
        }

        _ = ensureGroup("")
        for file in files {
            let name = (file as NSString).lastPathComponent
            let dir = (file as NSString).deletingLastPathComponent
            let fileId = objectId("file:" + file)
            let buildId = objectId("build:" + file)
            fileRefs.append("\t\t\(fileId) /* \(name) */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"\(name)\"; sourceTree = \"<group>\"; };")
            buildFiles.append("\t\t\(buildId) /* \(name) in Sources */ = {isa = PBXBuildFile; fileRef = \(fileId) /* \(name) */; };")
            sourcesEntries.append("\t\t\t\t\(buildId) /* \(name) in Sources */,")
            outputPaths.append("\t\t\t\t\"$(SRCROOT)/\(generatedRelative)/\(file)\",")
            let groupIdForFile = ensureGroup(dir)
            groups[groupIdForFile]!.children.append("\(fileId) /* \(name) */")
        }

        var groupBlocks: [String] = []
        for id in groupOrder {
            let group = groups[id]!
            var block = "\t\t\(id) /* \(group.name) */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
            for child in group.children { block += "\t\t\t\t\(child),\n" }
            block += "\t\t\t);\n\t\t\tpath = \(group.path);\n\t\t\tsourceTree = \"<group>\";\n\t\t};"
            groupBlocks.append(block)
        }

        let scriptId = objectId("script:" + generatedRelative)
        // La fase corre spock-gen en cada build: con la caché al día es una comprobación de hashes
        // (cache HIT), y si falta un archivo, cambió el dominio o apareció un @Stubbed/@Mocking nuevo,
        // regenera y sincroniza el proyecto. Se ejecuta con un entorno limpio para que SwiftPM
        // comparta la caché de .build con la terminal en vez de recompilar el generador.
        let script = """
        # Spock: la carpeta Generated es el snapshot de stubs y mocks.
        # Cada build corre spock-gen; con todo al día termina en milisegundos (cache HIT).
        # Deja rastro en .build/spock-phase.log junto al Package.swift.
        LOG="${SRCROOT}/\(packageRelative)/.build/spock-phase.log"
        mkdir -p "$(dirname "$LOG")"
        START=$(date +%s)
        cd "${SRCROOT}/\(packageRelative)"
        /usr/bin/env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" DEVELOPER_DIR="${DEVELOPER_DIR}" \(request.generateCommand) >> "$LOG" 2>&1
        STATUS=$?
        echo "$(date '+%F %T') spock-gen terminó con código $STATUS en $(( $(date +%s) - START )) s" >> "$LOG"
        exit $STATUS
        """
        let scriptBlock = """
        \t\t\(scriptId) /* \(scriptPhaseName) */ = {
        \t\t\tisa = PBXShellScriptBuildPhase;
        \t\t\talwaysOutOfDate = 1;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t);
        \t\t\tinputFileListPaths = (
        \t\t\t);
        \t\t\tinputPaths = (
        \t\t\t);
        \t\t\tname = "\(scriptPhaseName)";
        \t\t\toutputFileListPaths = (
        \t\t\t);
        \t\t\toutputPaths = (
        \(outputPaths.joined(separator: "\n"))
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t\tshellPath = /bin/sh;
        \t\t\tshellScript = "\(pbxEscaped(script))";
        \t\t\tshowEnvVarsInLog = 0;
        \t\t};
        """

        // Insertar
        content = insert(buildFiles.joined(separator: "\n") + "\n", afterSection: "PBXBuildFile", in: content)
        content = insert(fileRefs.joined(separator: "\n") + "\n", afterSection: "PBXFileReference", in: content)
        content = insert(groupBlocks.joined(separator: "\n") + "\n", afterSection: "PBXGroup", in: content)
        content = insertChild("\(groupOrder[0]) /* \(generatedFolderName) */", intoGroup: parentGroupId, in: content)
        content = insertScriptPhase(scriptBlock, in: content)
        content = insertSourcesEntries(sourcesEntries, intoPhase: sourcesPhaseId, in: content)
        content = insertBuildPhase("\(scriptId) /* \(scriptPhaseName) */", firstInTarget: request.targetName, in: content)

        if content == original {
            return .upToDate(filesCount: files.count)
        }
        try content.write(to: pbxURL, atomically: true, encoding: .utf8)
        return .synchronized(filesCount: files.count)
    }

    // MARK: - Limpieza de objetos gestionados

    /// Quita todo objeto o referencia cuyo identificador lleva el prefijo de spock-gen,
    /// incluido un grupo sincronizado `Generated` de una configuración anterior.
    static func removeManagedObjects(from content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var skippingBlock = false

        let managedOneLiner = try! NSRegularExpression(pattern: #"^\t\t\#(objectPrefix)\w{16} /\* .* \*/ = \{.*\};\s*$"#)
        let managedBlockStart = try! NSRegularExpression(pattern: #"^\t\t\#(objectPrefix)\w{16} /\* .* \*/ = \{\s*$"#)
        let managedReference = try! NSRegularExpression(pattern: #"^\t+\#(objectPrefix)\w{16} /\* .* \*/,\s*$"#)

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if skippingBlock {
                if line == "\t\t};" { skippingBlock = false }
                continue
            }
            if managedOneLiner.firstMatch(in: line, range: range) != nil { continue }
            if managedReference.firstMatch(in: line, range: range) != nil { continue }
            if managedBlockStart.firstMatch(in: line, range: range) != nil {
                skippingBlock = true
                continue
            }
            result.append(line)
        }
        lines = result

        var text = lines.joined(separator: "\n")
        // Listas vacías que pudieron quedar
        text = text.replacingOccurrences(of: "\t\t\tfileSystemSynchronizedGroups = (\n\t\t\t);\n", with: "")
        // Secciones vacías
        for section in ["PBXFileSystemSynchronizedRootGroup", "PBXShellScriptBuildPhase"] {
            text = text.replacingOccurrences(of: "/* Begin \(section) section */\n/* End \(section) section */\n\n", with: "")
        }
        return text
    }

    // MARK: - Helpers de texto

    static func objectId(_ key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02X", $0) }.joined()
        return objectPrefix + String(hex.prefix(16))
    }

    static func generatedSwiftFiles(in directory: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: directory.path) else { return [] }
        var files: [String] = []
        while let element = enumerator.nextObject() as? String {
            if element.hasSuffix(".swift") { files.append(element) }
        }
        return files.sorted()
    }

    static func relativePath(from base: URL, to target: URL) -> String {
        let baseParts = base.standardizedFileURL.pathComponents
        let targetParts = target.standardizedFileURL.pathComponents
        var common = 0
        while common < baseParts.count, common < targetParts.count, baseParts[common] == targetParts[common] {
            common += 1
        }
        let ups = Array(repeating: "..", count: baseParts.count - common)
        let downs = Array(targetParts[common...])
        let parts = ups + downs
        return parts.isEmpty ? "." : parts.joined(separator: "/")
    }

    static func pbxEscaped(_ script: String) -> String {
        script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    static func nativeTargetBlock(named name: String, in content: String) -> String? {
        let pattern = #"\t\t\w{24} /\* [^*]+ \*/ = \{\n\t\t\tisa = PBXNativeTarget;(?:.|\n)*?\n\t\t\};"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for match in regex.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
            guard let range = Range(match.range, in: content) else { continue }
            let block = String(content[range])
            if block.contains("\n\t\t\tname = \(name);\n") || block.contains("\n\t\t\tname = \"\(name)\";\n") {
                return block
            }
        }
        return nil
    }

    /// Un bloque PBXGroup no contiene `}` hasta su cierre, así `[^}]*?` evita cruzar al grupo siguiente.
    static func groupId(withPath path: String, in content: String) -> String? {
        let pattern = #"\t\t(\w{24}) /\* [^*]+ \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \([^}]*?\n\t\t\t\);\n(?:\t\t\tname = [^\n]+\n)?\t\t\tpath = "?\#(NSRegularExpression.escapedPattern(for: path))"?;"#
        return firstMatch(pattern, in: content)
    }

    static func mainGroupId(in content: String) -> String? {
        firstMatch(#"mainGroup = (\w{24})"#, in: content)
    }

    static func insert(_ text: String, afterSection section: String, in content: String) -> String {
        let marker = "/* Begin \(section) section */\n"
        guard let range = content.range(of: marker) else { return content }
        return content.replacingCharacters(in: range, with: marker + text)
    }

    static func insertChild(_ child: String, intoGroup groupId: String, in content: String) -> String {
        // children = ( ... ); del grupo indicado: insertar antes del cierre de la lista
        let pattern = #"(\t\t\#(groupId) /\* [^*]+ \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \([^}]*?)(\n\t\t\t\);)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let insertAt = Range(match.range(at: 2), in: content) else { return content }
        return content.replacingCharacters(in: insertAt, with: "\n\t\t\t\t\(child)," + String(content[insertAt]))
    }

    static func insertScriptPhase(_ block: String, in content: String) -> String {
        let marker = "/* Begin PBXShellScriptBuildPhase section */\n"
        if let range = content.range(of: marker) {
            return content.replacingCharacters(in: range, with: marker + block + "\n")
        }
        let sourcesMarker = "/* Begin PBXSourcesBuildPhase section */\n"
        guard let range = content.range(of: sourcesMarker) else { return content }
        let section = marker + block + "\n/* End PBXShellScriptBuildPhase section */\n\n"
        return content.replacingCharacters(in: range, with: section + sourcesMarker)
    }

    static func insertSourcesEntries(_ entries: [String], intoPhase phaseId: String, in content: String) -> String {
        guard !entries.isEmpty else { return content }
        let pattern = #"(\t\t\#(phaseId) /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = \d+;\n\t\t\tfiles = \(\n)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else { return content }
        return content.replacingCharacters(in: range, with: String(content[range]) + entries.joined(separator: "\n") + "\n")
    }

    static func insertBuildPhase(_ phase: String, firstInTarget targetName: String, in content: String) -> String {
        guard let block = nativeTargetBlock(named: targetName, in: content),
              let blockRange = content.range(of: block),
              let phasesRange = block.range(of: "\t\t\tbuildPhases = (\n") else { return content }
        let updated = block.replacingCharacters(in: phasesRange, with: "\t\t\tbuildPhases = (\n\t\t\t\t\(phase),\n")
        return content.replacingCharacters(in: blockRange, with: updated)
    }
}
