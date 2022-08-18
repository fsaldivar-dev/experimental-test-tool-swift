//
//  Mocks.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 11/08/22.
//

import Foundation
import SpockSwift

extension User: SpockDummy, Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.acount == rhs.acount &&
        lhs.address == rhs.address &&
        lhs.name == rhs.name &&
        lhs.phone == rhs.phone &&
        lhs.age == rhs.age &&
        lhs.email == rhs.email
    }
}

extension Address: SpockDummy, Equatable {
    static func == (lhs: Address, rhs: Address) -> Bool {
        lhs.stret == rhs.stret &&
        lhs.cp == rhs.cp &&
        lhs.intNumber == rhs.intNumber &&
        lhs.extNumber == rhs.extNumber
    }
}

extension Account: SpockDummy, Equatable {
    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.numberAcount == rhs.numberAcount &&
        lhs.serialID == rhs.serialID
    }
}

final class MockInteractor: Interactor, SpockMock {
    
    
    var fetchAllUserAction: Stub<(), [User]> = .init()
    func fetchAllUser() async throws -> [User] {
        try fetchAllUserAction.onCall(()) ?? []
    }
    
    @Stubbed<Int, User>
    var fetchUserAction
    func fetchUser(at serialID: Int) async throws -> User {
        try fetchUserAction.onCall(serialID) ?? User.dummy()
    }
    
    @Stubbed<Int, User>
    var searchParentsAction
    func searchParents(at serialID: Int) async throws -> User {
        try searchParentsAction.onCall(serialID) ?? User.dummy()
    }
}


final class MockView: View, SpockMock {
    
    @Stubbed<[User], Void>
    var loadUserListAction
    @MainActor
    func loadUserList(userList: [User]) {
        try? loadUserListAction.onCall(userList)
    }
    
    @Stubbed<User, Void>
    var showParentsAction
    @MainActor
    func showParents(user: User) {
        try? showParentsAction.onCall(user)
    }
}

final class MockTask: TaskCustom {
    @Stubbed<() async throws -> Void, Void>
    var runAction
    func run(_ task: @escaping () async throws -> Void ) {
        try? runAction.onCall(task)
    }
}
