//
//  UserStubTests.swift
//  ExampleTests
//
//  Created for SpockSwift 2 Example.
//

import Testing
import SpockSwift
@testable import Example

// Anotación declarativa @Stub:
// autoTree descubrirá automáticamente Profile y Pet recursivamente!
@Stub
extension User {}

@Stub
struct TestCustomModel {
    var some: String
}
@Stub
struct NewName {
    var name: String
}

struct Some {
    var nome: String
}
@Stub
extension Some {}

@Suite("Example - Stubs y autoTree")
struct UserStubTests {

    @Test("User.stub() se genera con valores default y árbol de dependencias")
    func testUserStubDefault() {
        let user = User.stub()

        #expect(!user.name.isEmpty)
        #expect(user.role == .admin)
        // autoTree cascaded stub:
        #expect(!user.profile.bio.isEmpty)
        #expect(!user.profile.pet.name.isEmpty)
    }

    @Test("User.stub(...) permite sobreescribir campos de forma tipada")
    func testUserStubCustom() {
        let customUser = User.stub(
            name: "Francisco",
            role: .member,
            profile: .stub(
                bio: "Software Architect",
                pet: .stub(name: "Firulais", age: 3)
            )
        )

        #expect(customUser.name == "Francisco")
        #expect(customUser.role == .member)
        #expect(customUser.profile.bio == "Software Architect")
        #expect(customUser.profile.pet.name == "Firulais")
        #expect(customUser.profile.pet.age == 3)
    }

    @Test("TestCustomModel.stub() generado automáticamente desde @Stub struct en tests")
    func testCustomModelStub() {
        let model = TestCustomModel.stub()
        #expect(model.some == "dummy_some")

        let custom = TestCustomModel.stub(some: "Hola Mundo")
        #expect(custom.some == "Hola Mundo")
    }
}
