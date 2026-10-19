//
//  SpockSpy.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 10/08/22.
//

import Foundation

public final class Spy<Parameters, Stubbed>: @unchecked Sendable {
    private let lock = NSLock()
    private var _isInvoked: Bool = false
    private var _invokedCount: Int = 0
    private var _history: [Parameters]?
    private var _parameter: Parameters?
    private var _stubbed: Stubbed?

    public var isInvoked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isInvoked
    }

    public var invokedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _invokedCount
    }

    public var history: [Parameters]? {
        lock.lock()
        defer { lock.unlock() }
        return _history
    }

    public var parameter: Parameters? {
        lock.lock()
        defer { lock.unlock() }
        return _parameter
    }

    public var stubbed: Stubbed? {
        lock.lock()
        defer { lock.unlock() }
        return _stubbed
    }

    public init() {}

    public func register(_ parameters: Parameters, stubbed: Stubbed?) {
        lock.lock()
        defer { lock.unlock() }
        _isInvoked = true
        _invokedCount += 1
        _parameter = parameters
        _stubbed = stubbed
        if _history == nil {
            _history = []
        }
        _history?.append(parameters)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _isInvoked = false
        _invokedCount = 0
        _parameter = nil
        _stubbed = nil
        _history = nil
    }
}

public final class Stub<Parameters, Stubbed>: @unchecked Sendable {
    private let lock = NSLock()
    private let spy: Spy<Parameters, Stubbed> = .init()
    private var thatReturn: ((Parameters) throws -> Stubbed?)?

    public init() {}

    public func whenRun(thatReturn: @escaping (Parameters) throws -> Stubbed?) {
        lock.lock()
        defer { lock.unlock() }
        self.thatReturn = thatReturn
    }

    public func onCall(_ params: Parameters) throws -> Stubbed? {
        let action: ((Parameters) throws -> Stubbed?)? = {
            lock.lock()
            defer { lock.unlock() }
            return thatReturn
        }()

        if let action = action {
            let result = try action(params)
            spy.register(params, stubbed: result)
            return result
        }

        spy.register(params, stubbed: nil)
        return nil
    }

    public func getSpy() -> Spy<Parameters, Stubbed> {
        spy
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        thatReturn = nil
        spy.reset()
    }
}

@propertyWrapper
public final class Stubbed<I, O>: @unchecked Sendable {
    public var wrappedValue: Stub<I, O> = .init()
    public init() {}
}
