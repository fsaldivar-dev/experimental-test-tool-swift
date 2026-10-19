//
//  StubMacroSyntaxTest.swift
//  SpockSwiftTests
//
//  Created for SpockSwift 2.
//

import Foundation
import SpockSwift
import XCTest

struct SampleUser {
    let name: String
    let age: Int
}

// Verifica que el macro @Stub se adjunta limpiamente a una extensión sin error del compilador
@Stub
extension SampleUser {
    // Extensión decorada con @Stub
}

final class StubMacroSyntaxTest: XCTestCase {
    func testStubMacroSyntaxCompiles() {
        let user = SampleUser(name: "Francisco", age: 30)
        XCTAssertEqual(user.name, "Francisco")
        XCTAssertEqual(user.age, 30)
    }
}
