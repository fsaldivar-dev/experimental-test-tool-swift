//
//  UserStubTests.swift
//  ExampleTests
//
//  Created for SpockSwift 2 Example.
//

import Testing
import SpockSwift
@testable import Example

// Anotación declarativa @Stubbed:
// autoTree descubrirá automáticamente Profile y Pet recursivamente!
@Stubbed
extension User {}

@Stubbed
extension SomeStub {}

@Suite("Example - Stubs y autoTree")
struct UserStubTests {

    @Test("User.stub() se genera con valores deterministas con sentido y árbol de dependencias")
    func testUserStubDefault() {
        let user = User.stub()

        #expect(user.name == "Ana García")
        #expect(user.email == "ana.garcia@example.com")
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
        #expect(some.named == "dummy_named", "sin regla para 'named', queda el valor plano")
        #expect(some.age == 30, "'age' sí tiene regla")

        let custom = SomeStub.stub(named: "Spock", age: 42)
        #expect(custom.named == "Spock")
        #expect(custom.age == 42)
    }


    @Test("User.stubs(count:) entrega instancias con identidad distinta")
    func testUserStubs() {
        let users = User.stubs(count: 3)

        #expect(users.map(\.id) == [1, 2, 3])
        #expect(users.map(\.name) == ["Ana García 1", "Ana García 2", "Ana García 3"])
        #expect(users[1].email == "ana.garcia2@example.com")
        #expect(User.stubs(count: 0).isEmpty)
    }
}
