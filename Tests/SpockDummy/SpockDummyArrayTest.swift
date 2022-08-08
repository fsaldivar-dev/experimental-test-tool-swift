//
//  SpockDummyArrayTest.swift
//  Spockwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//

@testable import Spockwift

import class XCTest.XCTestCase
import func XCTest.XCTAssertNotNil
import func XCTest.XCTAssert
import func XCTest.XCTFail
import func XCTest.XCTAssertNil

extension Array: SpockDummy where Element: Codable {}

final class SpockDummyArrayTest: XCTestCase {
    
    func testArrayDefault() throws {
        let list = try ListObject.dummy()
        XCTAssertNotNil(list)
    }
    
    func testArrayCustom() throws {
        let dates: [Date] = [Date(), Date(), Date(), Date(), Date()]
        let boleans: [Bool] = [true, false, true, true]
        let users: [User] = [
            try User.dummy(),
            try User.dummy(with: .init(at: "name", with: "Javi")),
            try User.dummy(with: .init(at: "name", with: "Javi"),
                           .init(at: "profession:name", with: "Developer"))
        ]
        
        let list = try ListObject.dummy(with: .init(at: "numbers", with: [1,2,3]),
                                        .init(at: "names", with: ["name1", "name2", "name3"]),
                                        .init(at: "dates", with: dates),
                                        .init(at: "boleans", with: boleans),
                                        .init(at: "users", with: users)
        )
        XCTAssert(list.numbers.containsSameElements(as: [1,2,3]))
        XCTAssert(list.names.containsSameElements(as: ["name1", "name2", "name3"]))
        XCTAssert(list.boleans.difference(from: boleans).count == 0)
        XCTAssert(list.dates.containsSameElements(as: dates))
        guard let dummyUser = list.users else {
            XCTFail("Error, not set dummy value")
            return
        }
        XCTAssert(dummyUser.difference(from: users).count == 0)
    }
    
    func testArrayCustomWithGenerato() throws {
        
        let dates: [Date] = [Date(), Date(), Date(), Date(), Date()]
        let boleans: [Bool] = [true, false, true, true]
        let users: [User] = [
            try User.dummy(),
            try User.dummy(with: .init(at: "name", with: "Javi")),
            try User.dummy(with: .init(at: "name", with: "Javi"),
                           .init(at: "profession:name", with: "Developer"))
        ]
        
        
        
        let list = try SpockDummyGenerator<ListObject>()
            .setDummyValue(at: "numbers", with: [1,2,3])
            .setDummyValue(at: "names", with: ["name1", "name2", "name3"])
            .setDummyValue(at: "boleans", with: boleans)
            .setDummyValue(at: "dates", with: dates)
            .setDummyValue(at: "users", with: users)
            .generate()
        
        XCTAssert(list.numbers.containsSameElements(as: [1,2,3]))
        XCTAssert(list.names.containsSameElements(as: ["name1", "name2", "name3"]))
        XCTAssert(list.boleans.difference(from: boleans).count == 0)
        XCTAssert(list.dates.containsSameElements(as: dates))
        guard let dummyUser = list.users else {
            XCTFail("Error, not set dummy value")
            return
        }
        XCTAssert(dummyUser.difference(from: users).count == 0)
    }

    
    func testArrayNils() throws {
        let list = try ListObject.dummy(with: .init(at: "users", with: nil))
        XCTAssertNil(list.users)
    }
    
    func testSympleArray() throws {
        let numbers: [Int]? = try .dummy()
        let names: [String]? = try .dummy()
        let dates: [Date]? = try .dummy()
        let boleans: [Bool]? = try .dummy()
        let users: [User]? = try .dummy()
        
        XCTAssertNotNil(numbers)
        XCTAssertNotNil(names)
        XCTAssertNotNil(dates)
        XCTAssertNotNil(boleans)
        XCTAssertNotNil(users)
    }
}
