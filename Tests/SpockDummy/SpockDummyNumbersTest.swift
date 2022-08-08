//
//  SpockDummyNumbersTest.swift
//  SpockSwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//

@testable import SpockSwift
import func XCTest.XCTAssertEqual
import class XCTest.XCTestCase

final class SpockDummyNumbersTest: XCTestCase {

    func testNumberDefault() throws {
        let figure: Figure = try Figure.dummy()
        XCTAssertEqual(figure.number, 0)
        XCTAssertEqual(figure.counter, 0)
        XCTAssertEqual(figure.float, 0)
        XCTAssertEqual(figure.double, 0)
        XCTAssertEqual(figure.figure.number, 0)
        XCTAssertEqual(figure.figure.counter, 0)
        XCTAssertEqual(figure.figure.float, 0)
        XCTAssertEqual(figure.figure.double, 0)
    }
    
    func testNumberCustomData() throws {
        let figure: Figure = try Figure
            .dummy(with: .init(at: "number", with: 10),
                   .init(at: "counter", with: 5),
                   .init(at: "double", with: Double(20)),
                   .init(at: "float", with: Float(10)),
                   .init(at: "figure:float", with: Float(14)),
                   .init(at: "figure:number", with: 29),
                   .init(at: "figure:counter", with: -20),
                   .init(at: "figure:double", with: Double(13.1416))
        )
        
        XCTAssertEqual(figure.number, 10)
        XCTAssertEqual(figure.counter, 5)
        XCTAssertEqual(figure.float, 10.0)
        XCTAssertEqual(figure.double, 20)
        XCTAssertEqual(figure.figure.number, 29)
        XCTAssertEqual(figure.figure.counter, -20)
        XCTAssertEqual(figure.figure.float, 14)
        XCTAssertEqual(figure.figure.double, 13.1416)
    }
    
    func testNumberCustomNil() throws {
        let figure: Figure = try Figure
            .dummy(with: .init(at: "float", with: nil),
                   .init(at: "figure:float", with: nil)
        )

        XCTAssertEqual(figure.number, 0)
        XCTAssertEqual(figure.counter, 0)
        XCTAssertEqual(figure.float, nil)
        XCTAssertEqual(figure.double, 0)
        XCTAssertEqual(figure.figure.number, 0)
        XCTAssertEqual(figure.figure.counter, 0)
        XCTAssertEqual(figure.figure.float, nil)
        XCTAssertEqual(figure.figure.double, 0)

    }

}
