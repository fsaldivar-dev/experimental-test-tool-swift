//
//  SpockSpy.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 10/08/22.
//

public final class Spy<Parameters, Stubbed> {
    private(set) var isInvoked: Bool = false
    private(set) var invokedCount: Int = 0
    private(set) var history: Array<Parameters>?
    private(set) var parameter: Parameters?
    private(set) var stubbed: Stubbed?

    public init() {
        // Intentionally unimplemented...
    }
    
    public func register(_ parameters: Parameters, stubbed: Stubbed?) {
        isInvoked = true
        invokedCount += 1
        self.parameter = parameters
        self.stubbed = stubbed
    }
}

public final class Stub<Parameters, Stubbed> {
    private var stubbed: Stubbed!
    private var spy: Spy<Parameters, Stubbed> = .init()
    private var thatReturn: ((Parameters) throws -> Stubbed?)!

    public init() {
        // Intentionally unimplemented...
    }
    
    public func whenRun(thatReturn: @escaping (Parameters) throws -> Stubbed?) {
        self.thatReturn = thatReturn
    }

    public func onCall(_ params: Parameters) throws -> Stubbed? {
        if let action = thatReturn {
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

    deinit {
        thatReturn = nil
        stubbed = nil
    }
}

@propertyWrapper
public final class Stubbed<I, O> {
    public var wrappedValue: Stub<I, O> = .init()
    public init() {
        // Intentionally unimplemented...
    }
}
