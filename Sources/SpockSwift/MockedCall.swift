//
//  MockedCall.swift
//  SpockSwift
//
//  Created for SpockSwift 2.
//

import Foundation

/// Estado compartido de una llamada mockeada: lo programado y lo registrado.
final class MockedCallState<I, O>: @unchecked Sendable {
    private let lock = NSLock()
    private var runHook: ((I) -> Void)?
    private var returnHook: ((I) -> O)?
    private var throwHook: ((I) -> Error?)?
    private var invocations: [I] = []

    init() {}

    func setRun(_ hook: @escaping (I) -> Void) {
        lock.lock(); defer { lock.unlock() }
        runHook = hook
    }

    func setReturns(_ hook: @escaping (I) -> O) {
        lock.lock(); defer { lock.unlock() }
        returnHook = hook
    }

    func setThrows(_ hook: @escaping (I) -> Error?) {
        lock.lock(); defer { lock.unlock() }
        throwHook = hook
    }

    /// Registra (si procede), ejecuta `run`, lanza si `throws` lo pide y devuelve lo de `returns`.
    func invoke(_ params: I, recording: Bool) throws -> O? {
        let (run, returns, throwing): (((I) -> Void)?, ((I) -> O)?, ((I) -> Error?)?) = {
            lock.lock(); defer { lock.unlock() }
            if recording { invocations.append(params) }
            return (runHook, returnHook, throwHook)
        }()

        run?(params)
        if let error = throwing?(params) {
            throw error
        }
        return returns?(params)
    }

    var history: [I] {
        lock.lock(); defer { lock.unlock() }
        return invocations
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        runHook = nil
        returnHook = nil
        throwHook = nil
        invocations.removeAll()
    }
}

/// Lo que todo doble de llamada ofrece para verificar: `called()`, `count`, `history`, `last`.
public protocol MockedCallVerification {
    associatedtype Parameters
    /// Todas las invocaciones registradas, en orden.
    var history: [Parameters] { get }
}

extension MockedCallVerification {
    public var count: Int { history.count }
    public var last: Parameters? { history.last }

    /// `true` si se invocó al menos una vez.
    public func called() -> Bool { !history.isEmpty }

    /// `true` si se invocó exactamente `times` veces.
    public func called(times: Int) -> Bool { history.count == times }

    /// `true` si alguna invocación cumple el predicado. Útil cuando los parámetros son una tupla.
    public func called(where predicate: (Parameters) -> Bool) -> Bool { history.contains(where: predicate) }
}

extension MockedCallVerification where Parameters: Equatable {
    /// `true` si alguna invocación recibió exactamente estos parámetros.
    public func called(with parameters: Parameters) -> Bool { history.contains(parameters) }
}

/// Llamada mockeada de un método que no lanza.
///
/// ```swift
/// mock.whenCall(\.fetch).run { id, completion in completion(.success(.stub())) }
/// mock.whenCall(\.name).returns("Ana")
/// #expect(mock.verify(\.fetch).called(where: { $0.id == 7 }))
/// ```
public final class MockedCall<I, O>: MockedCallVerification, @unchecked Sendable {
    private let state = MockedCallState<I, O>()

    public init() {}

    /// Efecto secundario en cada invocación: disparar un completion, mutar estado, contar.
    @discardableResult
    public func run(_ hook: @escaping (I) -> Void) -> Self {
        state.setRun(hook)
        return self
    }

    /// Valor fijo que devolverá cada invocación.
    @discardableResult
    public func returns(_ value: O) -> Self {
        state.setReturns { _ in value }
        return self
    }

    /// Valor calculado a partir de los parámetros.
    @discardableResult
    public func returns(_ hook: @escaping (I) -> O) -> Self {
        state.setReturns(hook)
        return self
    }

    /// La usa el mock generado. Devuelve `nil` si no hay `returns` programado, para que el
    /// cuerpo aplique su valor por defecto. `recording: false` para closures no escaping.
    @discardableResult
    public func invoke(_ params: I, recording: Bool = true) -> O? {
        try? state.invoke(params, recording: recording)
    }

    public var history: [I] { state.history }

    /// Olvida lo programado y lo registrado.
    public func reset() { state.reset() }
}

/// Llamada mockeada de un método `throws`. Igual que ``MockedCall`` más `throws`.
///
/// ```swift
/// mock.whenCall(\.fetch).throws(NetworkError.offline)
/// mock.whenCall(\.fetch).throws { id in id < 0 ? ValidationError.negative : nil }
/// ```
public final class MockedThrowingCall<I, O>: MockedCallVerification, @unchecked Sendable {
    private let state = MockedCallState<I, O>()

    public init() {}

    @discardableResult
    public func run(_ hook: @escaping (I) -> Void) -> Self {
        state.setRun(hook)
        return self
    }

    @discardableResult
    public func returns(_ value: O) -> Self {
        state.setReturns { _ in value }
        return self
    }

    @discardableResult
    public func returns(_ hook: @escaping (I) -> O) -> Self {
        state.setReturns(hook)
        return self
    }

    /// Error que lanzará cada invocación.
    @discardableResult
    public func `throws`(_ error: Error) -> Self {
        state.setThrows { _ in error }
        return self
    }

    /// Error decidido a partir de los parámetros; `nil` deja pasar a `returns`.
    @discardableResult
    public func `throws`(_ hook: @escaping (I) -> Error?) -> Self {
        state.setThrows(hook)
        return self
    }

    /// La usa el mock generado. Lanza si hay `throws` programado; devuelve `nil` si no hay `returns`.
    @discardableResult
    public func invoke(_ params: I, recording: Bool = true) throws -> O? {
        try state.invoke(params, recording: recording)
    }

    public var history: [I] { state.history }

    public func reset() { state.reset() }
}

/// Llamada espiada: solo registra. No se puede programar, por eso un espía nunca deja de delegar.
///
/// ```swift
/// #expect(spy.verify(\.fetchUser).called(with: 7))
/// #expect(spy.verify(\.saveUser).history.count == 2)
/// ```
public final class SpiedCall<I>: MockedCallVerification, @unchecked Sendable {
    private let lock = NSLock()
    private var invocations: [I] = []

    public init() {}

    /// La usa el espía generado antes de delegar en la implementación real.
    public func record(_ params: I) {
        lock.lock(); defer { lock.unlock() }
        invocations.append(params)
    }

    public var history: [I] {
        lock.lock(); defer { lock.unlock() }
        return invocations
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        invocations.removeAll()
    }
}
