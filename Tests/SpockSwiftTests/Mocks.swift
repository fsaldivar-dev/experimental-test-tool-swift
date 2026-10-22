//
//  Mocks.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 11/08/22.
//  Mocks escritos a mano con la misma forma que genera spock-gen.
//

import Foundation
import SpockSwift

extension MockUser: Equatable {
    static func == (lhs: MockUser, rhs: MockUser) -> Bool {
        lhs.acount == rhs.acount &&
        lhs.address == rhs.address &&
        lhs.name == rhs.name &&
        lhs.phone == rhs.phone &&
        lhs.age == rhs.age &&
        lhs.email == rhs.email
    }
}

extension Address: Equatable {
    static func == (lhs: Address, rhs: Address) -> Bool {
        lhs.stret == rhs.stret &&
        lhs.cp == rhs.cp &&
        lhs.intNumber == rhs.intNumber &&
        lhs.extNumber == rhs.extNumber
    }
}

extension Account: Equatable {
    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.numberAcount == rhs.numberAcount &&
        lhs.serialID == rhs.serialID
    }
}

final class MockInteractor: Interactor, SpockMock, @unchecked Sendable {

    struct Calls {
        let fetchAllUser = MockedThrowingCall<(), [MockUser]>()
        let fetchUser = MockedThrowingCall<Int, MockUser>()
        let searchParents = MockedThrowingCall<Int, MockUser>()
    }
    let calls = Calls()

    func fetchAllUser() async throws -> [MockUser] {
        try calls.fetchAllUser.invoke(()) ?? []
    }

    func fetchUser(at serialID: Int) async throws -> MockUser {
        try calls.fetchUser.invoke(serialID) ?? MockUser.stub()
    }

    func searchParents(at serialID: Int) async throws -> MockUser {
        try calls.searchParents.invoke(serialID) ?? MockUser.stub()
    }
}

final class MockView: View, SpockMock, @unchecked Sendable {

    struct Calls {
        let loadUserList = MockedCall<[MockUser], Void>()
        let showParents = MockedCall<MockUser, Void>()
    }
    let calls = Calls()

    @MainActor
    func loadUserList(userList: [MockUser]) {
        calls.loadUserList.invoke(userList)
    }

    @MainActor
    func showParents(user: MockUser) {
        calls.showParents.invoke(user)
    }
}

final class MockTask: TaskCustom, SpockMock, @unchecked Sendable {

    struct Calls {
        let run = MockedCall<@Sendable () async throws -> Void, Void>()
    }
    let calls = Calls()

    func run(_ task: @escaping @Sendable () async throws -> Void) {
        calls.run.invoke(task)
    }
}
