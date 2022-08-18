//
//  SpockMockTest.swift
//  SpockSwift-Unit-SpockDummy-Tests
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
        let listUserSpected: [User] = [
            try .dummy(with: .init(at: "name", with: "Fran")),
            try .dummy(with: .init(at: "name", with: "Javi"))
        ]
        // Arrage
        mockInteractor.fetchAllUserAction.whenRun { _ in
            listUserSpected
        }
        
        // Act
        presenter.loadData()
        try await mockTask.runAction.getSpy().parameter?()
        
        // Accert
        XCTAssert(mockInteractor.isInvoked(stub: { $0.fetchAllUserAction }))
        XCTAssert(mockView.isInvoked(stub: {$0.loadUserListAction}))
        XCTAssert(mockView.compare(stub: {$0.loadUserListAction}, to: listUserSpected))
    }
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
