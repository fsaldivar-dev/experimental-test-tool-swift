//
//  SpockMock.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 10/08/22.
//  Reescrito para SpockSwift 2.
//

/// Un mock: un doble sin comportamiento propio, hecho de llamadas mockeadas.
///
/// `spock-gen` genera la conformancia a partir de `@Mocking extension Protocolo {}`:
/// una tabla `Calls` con un ``MockedCall`` o ``MockedThrowingCall`` por requisito,
/// y un cuerpo por método que delega en ella.
///
/// ```swift
/// let repo = UserRepositoryMock()
/// repo.whenCall(\.fetchUser).returns(.stub(name: "Ana"))
/// repo.whenCall(\.saveUser).throws(StorageError.full)
///
/// try await sut.sync()
///
/// #expect(repo.verify(\.fetchUser).called(with: 7))
/// #expect(repo.verify(\.saveUser).count == 1)
/// ```
public protocol SpockMock {
    associatedtype Calls
    /// Tabla generada con una llamada mockeada por requisito del protocolo.
    var calls: Calls { get }
}

extension SpockMock {
    /// Programa qué hace una llamada: `run`, `returns` y, si el método lanza, `throws`.
    public func whenCall<I, O>(_ call: KeyPath<Calls, MockedCall<I, O>>) -> MockedCall<I, O> {
        calls[keyPath: call]
    }

    public func whenCall<I, O>(_ call: KeyPath<Calls, MockedThrowingCall<I, O>>) -> MockedThrowingCall<I, O> {
        calls[keyPath: call]
    }

    /// Pregunta qué pasó con una llamada: `called()`, `called(times:)`, `called(with:)`, `history`, `last`.
    public func verify<I, O>(_ call: KeyPath<Calls, MockedCall<I, O>>) -> MockedCall<I, O> {
        calls[keyPath: call]
    }

    public func verify<I, O>(_ call: KeyPath<Calls, MockedThrowingCall<I, O>>) -> MockedThrowingCall<I, O> {
        calls[keyPath: call]
    }
}
