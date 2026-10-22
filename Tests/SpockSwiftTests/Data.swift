//
//  File.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 11/08/22.
//

import Foundation

struct MockUser: Sendable {
    let name: String
    let email: String
    let phone: String
    let age: Int
    let address: Address
    let acount: Account
}

struct Address: Sendable {
    let stret: String
    let cp: String
    let intNumber: Int
    let extNumber: Int
}

struct Account: Sendable {
    var numberAcount: Int
    var serialID: Int
}

// Fixtures escritas a mano para los modelos de prueba (sustituyen al `.dummy()` de v1).
// En un proyecto real estas las generaría `spock-gen` con `@Stubbed`.
extension Account {
    static func stub(numberAcount: Int = 1, serialID: Int = 1) -> Account {
        Account(numberAcount: numberAcount, serialID: serialID)
    }
}

extension Address {
    static func stub(stret: String = "Av. Reforma 123", cp: String = "06600", intNumber: Int = 1, extNumber: Int = 10) -> Address {
        Address(stret: stret, cp: cp, intNumber: intNumber, extNumber: extNumber)
    }
}

extension MockUser {
    static func stub(
        name: String = "Ana García",
        email: String = "ana.garcia@example.com",
        phone: String = "+52 55 1234 5678",
        age: Int = 30,
        address: Address = .stub(),
        acount: Account = .stub()
    ) -> MockUser {
        MockUser(name: name, email: email, phone: phone, age: age, address: address, acount: acount)
    }
}

protocol Interactor: Sendable {
    func fetchAllUser() async throws -> [MockUser]
    func fetchUser(at serialID: Int) async throws -> MockUser
    func searchParents(at serialID: Int) async throws -> MockUser
}


protocol View: AnyObject, Sendable {
    @MainActor
    func loadUserList(userList: [MockUser])
    @MainActor
    func showParents(user: MockUser)
}

protocol Presenter: AnyObject {
    var view: View { get }
    var interactor: Interactor { get }
    
    func loadData()
    func selectedUser(user: MockUser)
}

protocol TaskCustom: Sendable {
    func run(_ task: @escaping @Sendable () async throws -> Void )
}

final class PresenterImpl: Presenter, @unchecked Sendable {
    var view: View
    
    var interactor: Interactor
    var task: TaskCustom
    init(view: View, interactor: Interactor, task: TaskCustom) {
        self.view = view
        self.interactor = interactor
        self.task = task
    }
    
    func loadData() {
        task.run {
            let userList = try await self.interactor.fetchAllUser()
            await self.view.loadUserList(userList: userList)
        }
    }
    
    func selectedUser(user: MockUser) {
        task.run {
            let user = try await self.interactor.searchParents(at: user.acount.serialID)
            await self.view.showParents(user: user)
        }
    }
}
