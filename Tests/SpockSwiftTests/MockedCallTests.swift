//
//  MockedCallTests.swift
//  SpockSwiftTests
//
//  Created for SpockSwift 2.
//

import XCTest
@testable import SpockSwift

final class MockedCallTests: XCTestCase {

    struct Boom: Error, Equatable {}

    // MARK: - returns

    func testInvokeWithoutReturnsGivesNil() {
        let call = MockedCall<Int, String>()
        XCTAssertNil(call.invoke(1))
        XCTAssertTrue(call.called())
    }

    func testReturnsFixedValueAndClosure() {
        let call = MockedCall<Int, String>()

        call.returns("fixed")
        XCTAssertEqual(call.invoke(1), "fixed")

        call.returns { "value_\($0)" }
        XCTAssertEqual(call.invoke(7), "value_7")
    }

    // MARK: - run

    func testRunExecutesBeforeReturnsAndWithoutReturns() {
        let call = MockedCall<Int, String>()
        var order: [String] = []

        call.run { _ in order.append("run") }
        XCTAssertNil(call.invoke(1))
        XCTAssertEqual(order, ["run"])

        call.returns { _ in order.append("returns"); return "ok" }
        XCTAssertEqual(call.invoke(2), "ok")
        XCTAssertEqual(order, ["run", "run", "returns"])
    }

    func testRunCanFireAnEscapingCompletionHandler() {
        let call = MockedCall<(id: Int, completion: (Result<String, Error>) -> Void), Void>()
        call.run { id, completion in completion(.success("user_\(id)")) }

        var received: Result<String, Error>?
        call.invoke((id: 3, completion: { received = $0 }))

        XCTAssertEqual(try received?.get(), "user_3")
        XCTAssertEqual(call.last?.id, 3)
    }

    // MARK: - throws

    func testThrowsFixedErrorAndStillRecords() {
        let call = MockedThrowingCall<Int, String>()
        call.returns("never")
        call.throws(Boom())

        XCTAssertThrowsError(try call.invoke(1)) { XCTAssertEqual($0 as? Boom, Boom()) }
        XCTAssertTrue(call.called(with: 1))
    }

    func testConditionalThrowsFallsThroughToReturns() throws {
        let call = MockedThrowingCall<Int, String>()
        call.returns { "ok_\($0)" }
        call.throws { $0 < 0 ? Boom() : nil }

        XCTAssertEqual(try call.invoke(1), "ok_1")
        XCTAssertThrowsError(try call.invoke(-1))
        XCTAssertEqual(call.count, 2)
    }

    // MARK: - verify

    func testVerificationHelpers() {
        let call = MockedCall<(a: Int, b: String), Void>()
        XCTAssertFalse(call.called())

        call.invoke((a: 1, b: "x"))
        call.invoke((a: 2, b: "y"))

        XCTAssertTrue(call.called())
        XCTAssertTrue(call.called(times: 2))
        XCTAssertFalse(call.called(times: 1))
        XCTAssertTrue(call.called(where: { $0.a == 2 && $0.b == "y" }))
        XCTAssertFalse(call.called(where: { $0.a == 3 }))
        XCTAssertEqual(call.history.map(\.a), [1, 2])
        XCTAssertEqual(call.last?.b, "y")
    }

    func testCalledWithForEquatableParameters() {
        let call = MockedCall<String, Void>()
        call.invoke("hello")
        XCTAssertTrue(call.called(with: "hello"))
        XCTAssertFalse(call.called(with: "bye"))
    }

    func testRecordingFalseRunsButDoesNotStore() {
        let call = MockedCall<() -> Void, Void>()
        var fired = 0
        call.run { body in body() }

        func sync(_ body: () -> Void) {
            withoutActuallyEscaping(body) { call.invoke($0, recording: false) }
        }
        sync { fired += 1 }

        XCTAssertEqual(fired, 1)
        XCTAssertFalse(call.called())
    }

    func testReset() {
        let call = MockedThrowingCall<Int, Int>()
        call.returns(1)
        call.throws(Boom())
        _ = try? call.invoke(1)

        call.reset()

        XCTAssertFalse(call.called())
        XCTAssertNil(call.last)
        XCTAssertNoThrow(try call.invoke(2))
        XCTAssertNil(try call.invoke(3))
    }

    // MARK: - Concurrencia

    func testConcurrentInvocationsAreCounted() async {
        let call = MockedCall<Int, String>()
        call.returns { "r_\($0)" }
        let iterations = 1_000

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask { _ = call.invoke(i) }
            }
        }

        XCTAssertTrue(call.called(times: iterations))
        XCTAssertEqual(Set(call.history).count, iterations)
    }

    // MARK: - whenCall / verify a través de SpockMock

    func testWhenCallAndVerifyResolveTheSameCall() {
        let view = MockView()
        view.whenCall(\.showParents).run { _ in }
        XCTAssertFalse(view.verify(\.showParents).called())

        view.calls.showParents.invoke(try! .dummy())
        XCTAssertTrue(view.verify(\.showParents).called(times: 1))
    }
}
