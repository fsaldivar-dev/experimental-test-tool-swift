//
//  SpockSpyTests.swift
//  SpockSwiftTests
//
//  Created for SpockSwift 2.
//

import XCTest
@testable import SpockSwift

final class SpockSpyTests: XCTestCase {

    func testSpyConcurrentRegistrations() async {
        let spy = Spy<Int, String>()
        let iterations = 1_000

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    spy.register(i, stubbed: "Result_\(i)")
                }
            }
        }

        XCTAssertTrue(spy.isInvoked)
        XCTAssertEqual(spy.invokedCount, iterations)
        XCTAssertEqual(spy.history?.count, iterations)
    }

    func testStubConcurrentCalls() async throws {
        let stub = Stub<Int, String>()
        stub.whenRun { num in
            "Return_\(num)"
        }

        let iterations = 1_000
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    _ = try? stub.onCall(i)
                }
            }
        }

        let spy = stub.getSpy()
        XCTAssertTrue(spy.isInvoked)
        XCTAssertEqual(spy.invokedCount, iterations)
    }

    func testSpyReset() {
        let spy = Spy<String, Int>()
        spy.register("input", stubbed: 42)
        XCTAssertTrue(spy.isInvoked)
        XCTAssertEqual(spy.invokedCount, 1)

        spy.reset()
        XCTAssertFalse(spy.isInvoked)
        XCTAssertEqual(spy.invokedCount, 0)
        XCTAssertNil(spy.parameter)
        XCTAssertNil(spy.stubbed)
        XCTAssertNil(spy.history)
    }
}
