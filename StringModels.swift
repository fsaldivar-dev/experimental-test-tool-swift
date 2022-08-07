//
//  StringModels.swift
//  Spockwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//

import Foundation
import Spockwift

struct User: Codable, SpockDummy {
    var name: String?
    var profession: Profession
}

struct Profession: Codable, SpockDummy {
    var name: String
    var university: University
}

struct University: Codable, SpockDummy {
    var name: String
    var country: String?
}
