//
//  StringModels.swift
//  Spockwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//

import Foundation
import Spockwift
//User:name
//User:profession:name
//User:profession:university:name
struct User: Codable, SpockDummy, Comparable {
    static func < (lhs: User, rhs: User) -> Bool {
        lhs == rhs
    }
    
    var name: String?
    var profession: Profession
}

struct Profession: Codable, SpockDummy, Comparable {
    static func < (lhs: Profession, rhs: Profession) -> Bool {
        lhs == rhs
    }
    
    var name: String
    var university: University

}

struct University: Codable, SpockDummy, Comparable {
    static func < (lhs: University, rhs: University) -> Bool {
        lhs == rhs
    }
    
    var name: String
    var country: String?
}


struct Figure: Codable, SpockDummy {
    var number: Int
    var counter: Int
    var float: Float?
    var double: Double
    var figure: Figure2
}

struct Figure2: Codable, SpockDummy {
    var number: Int
    var counter: Int
    var float: Float?
    var double: Double
}

struct ListObject: Codable, SpockDummy {
    var numbers: [Int]
    var names: [String]
    var dates: [Date]
    var boleans: [Bool]
    var users: [User]?
}



struct Perro {
    var name: String
    var age: Int
    var owner: User
    var brithDay: Date
}
