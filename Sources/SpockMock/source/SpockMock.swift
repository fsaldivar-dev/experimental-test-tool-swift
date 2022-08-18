//
//  SpockMock.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 10/08/22.
//

public protocol SpockMock {}

extension SpockMock {
    public func isInvoked<I,O>(stub: (Self) -> Stub<I, O>,
                               attep: Int = 1) -> Bool {
        let spy = stub(self).getSpy()
        return spy.isInvoked && spy.invokedCount == attep
    }
    
    public func compare<I,O>(stub: (Self) -> Stub<I, O>, isEqual: (I?) -> Bool ) -> Bool {
        let spy = stub(self).getSpy()
        return isEqual(spy.parameter)
    }
    
    public func compare<I: Equatable, O>(stub: (Self) -> Stub<I, O>, to: I?) -> Bool  {
        let spy = stub(self).getSpy()
        return spy.parameter == to
    }
}
