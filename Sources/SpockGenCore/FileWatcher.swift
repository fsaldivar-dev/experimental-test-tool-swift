//
//  FileWatcher.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
import Dispatch

/// Observador de sistema de archivos que monitorea cambios en Sources/ y Tests/
/// ejecutando generación reactiva al guardar (⌘S) sin requerir compilación manual.
public final class FileWatcher: @unchecked Sendable {
#if canImport(Darwin)
    private var sources: [DispatchSourceFileSystemObject] = []
#endif
    private var fileDescriptors: [Int32] = []
    private let queue = DispatchQueue(label: "com.spockswift.filewatcher", qos: .utility)
    private var debounceWorkItem: DispatchWorkItem?
    private var timerSource: DispatchSourceTimer?
    private let directories: [String]
    private var lastFileTimestamps: [String: Date] = [:]
    private let onChange: @Sendable () -> Void

    public init(directories: [String], onChange: @escaping @Sendable () -> Void) {
        self.directories = directories
        self.onChange = onChange
    }

    public func start() {
        stop()
        recordInitialTimestamps()

        // 1. Monitoreo por eventos del sistema de archivos (kqueue/DispatchSource, solo Apple).
        //    O_EVTONLY y makeFileSystemObjectSource no existen en Linux; allí basta el timer de abajo.
#if canImport(Darwin)
        let allDirs = collectAllDirectories(from: directories)
        for dir in allDirs {
            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else { continue }
            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib, .link, .rename],
                queue: queue
            )

            source.setEventHandler { [weak self] in
                self?.handleFileSystemEvent()
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            sources.append(source)
        }
#endif

        // 2. Timer de respaldo (polling suave cada 1s) para capturar guardados atómicos que reemplazan inodos
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .milliseconds(800))
        timer.setEventHandler { [weak self] in
            self?.checkTimestamps()
        }
        timer.resume()
        timerSource = timer
    }

    private func handleFileSystemEvent() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.triggerIfValid()
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + .milliseconds(120), execute: item)
    }

    private func checkTimestamps() {
        var hasChanges = false
        let current = scanCurrentTimestamps()

        // 1. Detectar archivos eliminados o agregados
        if current.count != lastFileTimestamps.count {
            hasChanges = true
        } else {
            // 2. Detectar refactors de rutas o archivos renombrados
            for file in lastFileTimestamps.keys {
                if current[file] == nil {
                    hasChanges = true
                    break
                }
            }
            // 3. Detectar modificaciones en archivos existentes
            if !hasChanges {
                for (file, lastDate) in current {
                    if let prevDate = lastFileTimestamps[file] {
                        if lastDate > prevDate {
                            hasChanges = true
                            break
                        }
                    } else {
                        hasChanges = true
                        break
                    }
                }
            }
        }

        if hasChanges {
            handleFileSystemEvent()
        }
    }

    private func triggerIfValid() {
        // Actualizar timestamps conocidos
        lastFileTimestamps = scanCurrentTimestamps()

        // Validar que ningún archivo modificado tenga errores de sintaxis incompletos
        var hasSyntaxErrors = false
        for (filePath, _) in lastFileTimestamps {
            if filePath.hasSuffix(".swift") && !filePath.hasSuffix(".generated.swift") {
                if SyntaxValidator.hasSyntaxErrors(fileURL: URL(fileURLWithPath: filePath)) {
                    hasSyntaxErrors = true
                    let fileName = (filePath as NSString).lastPathComponent
                    print("[SpockGen] ⏳ Sintaxis incompleta detectada en \(fileName). Esperando a que el archivo sea sintácticamente válido...")
                    break
                }
            }
        }

        if !hasSyntaxErrors {
            onChange()
        }
    }

    private func recordInitialTimestamps() {
        lastFileTimestamps = scanCurrentTimestamps()
    }

    private func scanCurrentTimestamps() -> [String: Date] {
        var result: [String: Date] = [:]
        let fileManager = FileManager.default

        for dir in directories {
            guard let enumerator = fileManager.enumerator(atPath: dir) else { continue }
            while let item = enumerator.nextObject() as? String {
                if item.hasSuffix(".swift") && !item.hasSuffix(".generated.swift") {
                    let fullPath = (dir as NSString).appendingPathComponent(item)
                    if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                       let modDate = attrs[.modificationDate] as? Date {
                        result[fullPath] = modDate
                    }
                }
            }
        }
        return result
    }

    private func collectAllDirectories(from roots: [String]) -> [String] {
        var result = Set<String>()
        let fileManager = FileManager.default

        for root in roots {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue {
                result.insert(root)
                if let enumerator = fileManager.enumerator(atPath: root) {
                    while let sub = enumerator.nextObject() as? String {
                        let full = (root as NSString).appendingPathComponent(sub)
                        var subIsDir: ObjCBool = false
                        if fileManager.fileExists(atPath: full, isDirectory: &subIsDir), subIsDir.boolValue {
                            result.insert(full)
                        }
                    }
                }
            }
        }
        return Array(result)
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        timerSource?.cancel()
        timerSource = nil
#if canImport(Darwin)
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
#endif
        fileDescriptors.removeAll()
    }

    deinit {
        stop()
    }
}
