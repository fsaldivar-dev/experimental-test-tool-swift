//
//  DaemonManager.swift
//  SpockGenCore
//
//  Created for SpockSwift 2.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct DaemonStatus: Sendable, Equatable {
    public var isRunning: Bool
    public var pid: Int32?
    public var logFilePath: String?

    public init(isRunning: Bool, pid: Int32? = nil, logFilePath: String? = nil) {
        self.isRunning = isRunning
        self.pid = pid
        self.logFilePath = logFilePath
    }
}

/// Administrador del demonio de fondo para SpockGen.
/// Permite iniciar, detener e inspeccionar el estado del proceso en segundo plano.
public final class DaemonManager: Sendable {
    public let pidFilePath: String
    public let logFilePath: String

    public init(
        pidFilePath: String = ".spock-daemon.pid",
        logFilePath: String = ".spock-daemon.log"
    ) {
        self.pidFilePath = pidFilePath
        self.logFilePath = logFilePath
    }

    /// Comprueba si el demonio se encuentra activo
    public func status() -> DaemonStatus {
        guard let pid = readPid() else {
            return DaemonStatus(isRunning: false, pid: nil, logFilePath: logFilePath)
        }

        // kill(pid, 0) evalúa si el proceso sigue activo sin enviarle ninguna señal destructiva
        if kill(pid, 0) == 0 {
            return DaemonStatus(isRunning: true, pid: pid, logFilePath: logFilePath)
        } else {
            // PID fantasma / proceso terminado previamente; limpiar archivo pid
            try? FileManager.default.removeItem(atPath: pidFilePath)
            return DaemonStatus(isRunning: false, pid: nil, logFilePath: logFilePath)
        }
    }

    /// Detiene el demonio en ejecución si está activo
    @discardableResult
    public func stop() -> Bool {
        let currentStatus = status()
        guard currentStatus.isRunning, let pid = currentStatus.pid else {
            // Si el archivo existía pero el proceso ya no estaba, asegurarse de limpiar
            try? FileManager.default.removeItem(atPath: pidFilePath)
            return false
        }

        // Enviar señal SIGTERM para terminación ordenada
        kill(pid, SIGTERM)

        // Breve espera para confirmar terminación
        usleep(50_000) // 50ms
        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }

        try? FileManager.default.removeItem(atPath: pidFilePath)
        return true
    }

    /// Guarda el PID del proceso en el archivo correspondiente
    public func savePid(_ pid: Int32) throws {
        let url = URL(fileURLWithPath: pidFilePath)
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        try "\(pid)\n".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    }

    /// Elimina el archivo de PID
    public func removePidFile() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    /// Lee el PID del archivo
    public func readPid() -> Int32? {
        guard let content = try? String(contentsOfFile: pidFilePath, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int32(trimmed)
    }
}
