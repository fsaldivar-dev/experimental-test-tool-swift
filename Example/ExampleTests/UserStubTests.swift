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
extension SomeStub {}

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

    @Test("SomeStub.stub() funciona correctamente")
    func testSomeStub() {
        let some = SomeStub.stub()
        #expect(some.named == "dummy_named")
        #expect(some.age == 0)

        let custom = SomeStub.stub(named: "Spock", age: 42)
        #expect(custom.named == "Spock")
        #expect(custom.age == 42)
    }

}
