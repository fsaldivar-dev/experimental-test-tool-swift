//
//  File.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 11/08/22.
//

import Foundation

struct User: Decodable {
    let name: String
    let email: String
    let phone: String
    let age: Int
    let address: Address
    let acount: Account
}

struct Address: Decodable {
    let stret: String
    let cp: String
    let intNumber: Int
    let extNumber: Int
}

struct Account: Decodable {
    var numberAcount: Int
    var serialID: Int
}

protocol Interactor {
    func fetchAllUser() async throws -> [User]
    func fetchUser(at serialID: Int) async throws -> User
    func searchParents(at serialID: Int) async throws -> User
}


protocol View {
    @MainActor
    func loadUserList(userList: [User])
    @MainActor
    func showParents(user: User)
}

protocol Presenter {
    var view: View { get }
    var interactor: Interactor { get }
    
    func loadData()
    func selectedUser(user: User)
}

protocol TaskCustom {
    func run(_ task: @escaping () async throws -> Void )
}

final class PresenterImpl: Presenter {
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
    
    func selectedUser(user: User) {
        task.run {
            let user = try await self.interactor.searchParents(at: user.acount.serialID)
            await self.view.showParents(user: user)
        }
    }
}
