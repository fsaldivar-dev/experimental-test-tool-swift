# SpockableDummy
| Caracteristica                 |     Estado    |     Test      |
| -----------------------------  | ------------- | ------------- |
| Soporte para datos primitivos  |       ✅      |       ✅       |
| Soporte para arreglos          |       ✅      |       ✅       |
| Soporte para objetos decodable |       ✅      |       ✅       |
| implementación de datos fake   |       ✅      |       ✅       |
|--------------------------------|---------------|-------------- |
| Soporte a diccionarios         |              ❌                |
| Documentación                  |              ❌                |

SpockableDummy es una librería creada para librarnos de la creación de objetos inecesarios, ejemplo
 si tengo algo así un modelo con variables que quiere usar para un test de una clase como esta

```Swift

struct Person: Codable {
    var name: String
    var lastName: String 
    var age: Int
}

final class RoomClass {
    private let teacher: Person
    privaate let studens: [Persons]
    
    ini(teacher: Person, students: [Persons]) {
        self.studens = students
        self.teacher = teacher
    }
    
    
    func getTeacherName() -> String {
        teacher.name
    }
    
    func getAllStudens() -> [students] {
        students
    }
}

```
Tendría que hacer ```Person(name: "dummy", lastName: "dummy", age: dummyNumber)``` y a su vez una lista de objetos dummy

```Swift
    final class RoomClassTest: XCTestCase {
        func testGetName() throws {
            /// Arrange
            let teacherDummy = Person(name: "dummy", lastName: "dummy", age: dummyNumber)
            let studentsDummy: [Person] = [] 
            /// Act
            let roomClass = Roomclass(teacher: teacherDummy, students)
            
            /// Accert
            XCTAccertEqual(roomclass.getTeacherName(), teacherDummy.name)
            
        }
    }
}
    
```
si bien el test de ejemplo, es muy simple, vemos que tengo que crear un objeto de tipo teacher con todos los valores dummy, como es solo una estructura no fue complicado, pero por ejemplo, si probamos la lista de usuarios

```Swift
    final class RoomClassTest: XCTestCase {
        func testGetName() throws {
            /// Arrange
            let teacherDummy = Person(name: "dummy", lastName: "dummy", age: dummyNumber)
            let studentsDummy: [Person] = [.init(name: "name1", lastName: "dummy", age: dummyNumber),
                        .init(name: "name2", lastName: "dummy", age: dummyNumber)] 
            /// Act
            let roomClass = Roomclass(teacher: teacherDummy, students)
            
            /// Accert
            XCTAccertEqual(roomclass.getAllStudens()[0].name, studentsDummy[0].name)
            XCTAccertEqual(roomclass.getAllStudens()[1].name, studentsDummy[1].name)
            
        }
    }
}
    
```

vemos que nuestra cantidad de código incremento un poco, por que tuvimos que crear el dummy de teacher sin tener la necesidad de usarlo, al igual variso datos de la lista como lastNAme, y age, dummys que tampoco estamos usando.

para esto esa librería considero el uso de encodable, con esta poderosa librería de ``serialización`` podemos crear dummys con muy pocas lineas, ejemplo: 

```Swift

    extension Person: SpockableDummy { }

    final class RoomClassTest: XCTestCase {
    
        func testGetName() throws {
            /// Arrange
            let teacherDummy = try Persson.dummy(with: .init(at: "name", with: "Fran")
            let studentsDummy: [Person] = try .dummy()
            /// Act
            let roomClass = Roomclass(teacher: teacherDummy, students)
            
            /// Accert
            XCTAccertEqual(roomclass.getTeacherName(), teacherDummy.name)
            
        }
        
                func testGetName() throws {
            /// Arrange
            let teacherDummy = try Person.dummy()
            let studentsDummy: [Person] = [.dummy(with: .init(at: "name", with: "Fran"),
                                           .dummy(with: .init(at: "name", with: "Javi")] 
            /// Act
            let roomClass = Roomclass(teacher: teacherDummy, students)
            
            /// Accert
            XCTAccertEqual(roomClass.getAllStudens()[0].name, studentsDummy[0].name)
            XCTAccertEqual(roomClass.getAllStudens()[1].name, studentsDummy[1].name)
            
        }
    }


```
Solo implementando ``SpockableDummy`` y el modelo con la implementación de códable podemos hacer uso de la función ``.dummy()``, esta función crea el objetos con valores primitivos por defecto.


