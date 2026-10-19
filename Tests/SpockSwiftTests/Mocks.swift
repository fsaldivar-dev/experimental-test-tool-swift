//
//  Mocks.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 11/08/22.
//

import Foundation
import SpockSwift

extension MockUser: SpockDummy, Equatable {
    static func == (lhs: MockUser, rhs: MockUser) -> Bool {
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

final class MockInteractor: Interactor, SpockMock, @unchecked Sendable {
    
    
    var fetchAllUserAction: Stub<(), [MockUser]> = .init()
    func fetchAllUser() async throws -> [MockUser] {
        try fetchAllUserAction.onCall(()) ?? []
    }
    
    @Stubbed<Int, MockUser>
    var fetchUserAction
    func fetchUser(at serialID: Int) async throws -> MockUser {
        try fetchUserAction.onCall(serialID) ?? MockUser.dummy()
    }
    
    @Stubbed<Int, MockUser>
    var searchParentsAction
    func searchParents(at serialID: Int) async throws -> MockUser {
        try searchParentsAction.onCall(serialID) ?? MockUser.dummy()
    }
}


final class MockView: View, SpockMock, @unchecked Sendable {
    
    @Stubbed<[MockUser], Void>
    var loadUserListAction
    @MainActor
    func loadUserList(userList: [MockUser]) {
        try? loadUserListAction.onCall(userList)
    }
    
    @Stubbed<MockUser, Void>
    var showParentsAction
    @MainActor
    func showParents(user: MockUser) {
        try? showParentsAction.onCall(user)
    }
}

final class MockTask: TaskCustom, @unchecked Sendable {
    @Stubbed<() async throws -> Void, Void>
    var runAction
    func run(_ task: @escaping @Sendable () async throws -> Void ) {
        try? runAction.onCall(task)
    }
}
