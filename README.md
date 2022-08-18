# experimental-test-tool-swift


<img width="640" alt="Captura de Pantalla 2022-08-08 a la(s) 7 07 24" src="https://user-images.githubusercontent.com/16517868/183414396-108611c1-8585-4ce5-8b4f-088ea4d15f04.png">

[![GitHub issues](https://img.shields.io/github/issues/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/issues)
[![GitHub forks](https://img.shields.io/github/forks/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/network)
[![GitHub stars](https://img.shields.io/github/stars/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/stargazers)
[![GitHub license](https://img.shields.io/github/license/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/blob/main/LICENSE.md)
![Cocoapods](https://img.shields.io/cocoapods/v/SpockSwift?style=for-the-badge)
![Cocoapods platforms](https://img.shields.io/cocoapods/p/SpockSwift?style=for-the-badge)

Pod creado para facilitar la creación de pruebas únitarias mediante código simple

# Roadmap

|                Roadmap             |    Estado     |
| -----------------------------------| ------------- |
| Crear código base                  | ✅            |
| SwiftPackage                       | ✅            |
| [CocoaPods](https://cocoapods.org) | ✅            |
| Example                            | ✅            |
| [Simple Dummy](./Sources/SpockDummy/assets//SpockableDummy.md)| ✅            |
| Spy                                | ⌛ 👨‍💻         |
| Mock                               | ⌛ 👨‍💻         |
| Stubed                             | ⌛ 👨‍💻         |
| UnitTest                           | ⌛ 👨‍💻         |
| Documentación                      | ⌛  👨‍💻        |
| Extensiones                        | ⌛  👨‍💻        |


### Swift Package Manager
Swift Package Manager es una herramienta para automatizar la distribución de código Swift y está integrado en el compilador Swift. Está en desarrollo temprano, pero experimental-annotation-swift admite su uso en plataformas compatibles.


Una vez que haya configurado su paquete Swift, agregar experimental-annotation-swift como dependencia es tan fácil como agregarlo al valor de dependencias de su Package.swift.
```swift
dependencies: [
    .package(url: "https://github.com/fsaldivar-dev/experimental-test-tool-swift", .upToNextMajor(from: "0.0.1"))
]
```

### CocoaPods
[CocoaPods](https://cocoapods.org) es un administrador de dependencias para proyectos Cocoa. Para obtener instrucciones de uso e instalación, visite su sitio web. Para integrar AnnotationSwift en su proyecto Xcode usando CocoaPods, especifíquelo en su `Podfile`:


```ruby
source 'https://github.com/CocoaPods/Specs.git'

# Integration tests
target 'YOUR_TESTING_TARGET' do
  pod SpockSwift, '0.0.1'
end
```

## [Dummy](./Sources/SpockDummy/assets//SpockableDummy.md)
**Definición**
Los objetos Dummy son objetos que no se utilizan en una prueba y solo actúan como marcadores de posición. Por lo general, no contiene ninguna implementación.
<details>
    <summary>Ejemplo</summary>
    
````Swift

struct User: Codable, SpockDummy {
  let name: String
  var lastName: String
  var age: Int
  var profession: Profession
}

struct Profession: Codable, SpockDummy {
  var name: String
  var university: University
}

struct University: Codable: SpockDummy {
   let name: String
   var country: String
}

let user: User = try .dummy()
print(user.name) // return ""
print(user.age) // return 0
print(user.profession.name) // return ""
print(user.profession.university.name) // return ""
print(user.profession.university.country) // return ""

let user = try Profession.dummy()
print(profession.name) // return ""
print(profession.university.name) // return ""
print(profession.university.country) // return ""

let university = try University.dummy()
print(university.name) // return ""
print(university.country) // return ""
````
</details>

## [Mock](./Sources/SpockMock/assets/SpockMock.md)

| Caracteristica                 |     Estado    |     Test      |
| -----------------------------  | ------------- | ------------- |
| Spy                            |       ✅      |       ✅       |
| Fake return                    |       ✅      |       ✅       |
|--------------------------------|---------------|--------------  |
| Soporte a diccionarios         |              ❌                |
| Documentación                  |              ❌                |

SpockMock librería creada para burlar implementación de funciones.

<details>
    <summary>Ejemplo</summary>
    
````Swift

struct User: Decodable {
    let name: String
    let email: String
    let phone: String
    let age: Int
}


protocol Interactor {
    func fetchAllUserAction() -> [Users]
}

protocol View {
    func showUers(users: [Users])
}

final class Presenter {
    private let interactor: Interactor
    private let view: View

    init(view: View, interactor: Interactor) {
      self.interactor = interactor
      self.view = view
    }
    
    func loadData() {
        let result = interactor.getFetchUsers()
        view.showUsers(users: result)
    }
}
````
    
### Mocks
   
````Swift
    
/// Create Mocks
final class MockInteractor: Interactor, SpockMock {
    @Stubbed<(), [User]>
    var fetchAllUserAction
    func fetchAllUser() -> [Users]
        try? fetchAllUserAction.onCall(()) ?? []
    }
}

final class MockView: View, SpockMock {
    
    @Stubbed<[User], Void>
    var showUersAction
    func showUers(users: [Users]) {
        try? loadUserListAction.onCall(userList)
    }
    
}    
````
   
#### Test
    
````Swift
    
extension User: SpockDummy, Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.name == rhs.name &&
        lhs.phone == rhs.phone &&
        lhs.age == rhs.age &&
        lhs.email == rhs.email
    }
}

    
final class SpockMockTest: XCTestCase {
    var presenter: Presenter!
    var mockInteractor = MockInteractor()
    var mockView = MockView()
    
    override func setUpWithError() throws {
        presenter = PresenterImpl(view: mockView,
                                  interactor: mockInteractor,
                                  task: mockTask)
    }

    override func tearDownWithError() throws {
        presenter = nil
    }

    func testLoadData() async throws {
         // Arrage
        /// Create dummy List
        let listUserSpected: [User] = [
            try .dummy(with: .init(at: "name", with: "Fran")),
            try .dummy(with: .init(at: "name", with: "Javi"))
        ]
        
        // wehn call fetchAllUser return list spected
        mockInteractor.fetchAllUserAction.whenRun { _ in
            listUserSpected
        }
        
        // Act, execute load data
        presenter.loadData()
        
        // Accert
        XCTAssert(mockInteractor.isInvoked(stub: { $0.fetchAllUserAction }))
        XCTAssert(mockView.isInvoked(stub: {$0.showUers}))
        XCTAssert(mockView.compare(stub: {$0.showUers}, to: listUserSpected))
    }
}

````
</details>

# Author & License

Proyecto creado por **Francisco Javier Saldivar** [![image](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](www.linkedin.com/in/fsaldivar-dev)


