//
//  SpockableDummyTest.swift
//  Spockwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//

import XCTest

@testable import Spockwift

final class SpockDummyStringTest: XCTestCase {

    func testStrings() throws {
        
        var user = try User.dummy(with:
                                    SpockDummyValue(at: "name", with: "Saldivar"),
                                    SpockDummyValue(at: "profession:name", with: "Developer"),
                                    SpockDummyValue(at: "profession:years", with: 10),
                                    SpockDummyValue(at: "profession:university:name", with: "UTEQ")
        )
        
        XCTAssertEqual(user.name, "Saldivar")
        XCTAssertEqual(user.profession.name, "Developer")
        XCTAssertEqual(user.profession.university.name, "UTEQ")
        XCTAssertNotNil(user.profession.university.country)
        
        
        let specName = "Francisco Saldivar"
        user.name = specName
        XCTAssertEqual(user.name, specName)
    }
    
    func testDefault() throws {
        let user = try User.dummy()
        XCTAssertNotNil(user.name)
        XCTAssertNotNil(user.profession.name)
        XCTAssertNotNil(user.profession.university.name)
        XCTAssertNotNil(user.profession.university.country)
    }

    func testNil() throws {
        var profession: Profession = try .dummy()
        profession.university.country = nil
        let user = try User.dummy(with:
                                    SpockDummyValue(at: "name", with: nil),
                                    SpockDummyValue(at: "profession", with: profession)
        )

        XCTAssertNil(user.name)
        XCTAssertNil(user.profession.university.country)
        
    }
    
    func testDog() throws {
        XCTAssertNoThrow(try Perro.dummy())
        
    }
}

extension Perro: SpockDummy {
    enum key: String, CodingKey {
        case name, age, owner, brithDay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Perro.key.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.age = try container.decode(Int.self, forKey: .age)
        self.brithDay = try container.decode(Date.self, forKey: .brithDay)
        self.owner = try container.decode(User.self, forKey: .owner)
    }
}
