//
//  SpockMockTest.swift
//  SpockSwiftTests
//
//  Created by Francisco Javier Saldivar Rubio on 11/08/22.
//

import XCTest
@testable import SpockSwift

final class SpockMockTest: XCTestCase {
    var presenter: Presenter!
    var mockInteractor = MockInteractor()
    var mockView = MockView()
    let mockTask = MockTask()

    override func setUpWithError() throws {
        presenter = PresenterImpl(view: mockView,
                                  interactor: mockInteractor,
                                  task: mockTask)
    }

    override func tearDownWithError() throws {
        presenter = nil
    }

    func testLoadData() async throws {
        let listUserSpected: [MockUser] = [
            .stub(name: "Fran"),
            .stub(name: "Javi")
        ]
        // Arrange
        mockInteractor.whenCall(\.fetchAllUser).returns(listUserSpected)

        // Act
        presenter.loadData()
        try await mockTask.verify(\.run).last?()

        // Assert
        XCTAssert(mockInteractor.verify(\.fetchAllUser).called())
        XCTAssert(mockView.verify(\.loadUserList).called(with: listUserSpected))
    }

    func testSelectedUserThrowsAreNotSwallowedByTheMock() async throws {
        struct Boom: Error {}
        let user: MockUser = .stub()
        mockInteractor.whenCall(\.searchParents).throws(Boom())

        presenter.selectedUser(user: user)
        let task = try XCTUnwrap(mockTask.verify(\.run).last)

        do {
            try await task()
            XCTFail("El interactor debió lanzar")
        } catch is Boom {
            XCTAssert(mockInteractor.verify(\.searchParents).called(with: user.acount.serialID))
            XCTAssertFalse(mockView.verify(\.showParents).called())
        }
    }

    func testPerformanceExample() throws {
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
