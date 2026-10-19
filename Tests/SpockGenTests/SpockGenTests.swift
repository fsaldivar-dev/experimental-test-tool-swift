//
//  SpockGenTests.swift
//  SpockGenTests
//
//  Created for SpockSwift 2.
//

import Testing
@testable import SpockGenCore

@Suite("SpockGenCore Base Tests")
struct SpockGenTests {
    @Test("Verifica la versión base del motor")
    func testEngineVersion() {
        let engine = SpockGenEngine()
        #expect(engine.version() == "2.0.0")
    }
}
