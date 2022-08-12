# SpockMock

| Caracteristica                 |     Estado    |     Test      |
| -----------------------------  | ------------- | ------------- |
| Spy                            |       ✅      |       ✅       |
| Fake return                     |       ✅      |       ✅       |
|--------------------------------|---------------|-------------- |
| Soporte a diccionarios         |              ❌                |
| Documentación                  |              ❌                |

SpockMock librería creada para burlar implementación de funciones.

## Ejercicio
Una buena practica es abstraer el comportamiento de nuestras clases a interfaces con el fin de realizar polimorfismo pero también nos ayuda para probar el comportamiento que una clase ejerce sobre otra,
revisando los protocolos anteriores, vemos que el protocolo ``presentador`` contiene el atributo ``View`` y el atributo  ``Interactor``, desde aquí podemos intuir que nuestro ``presenter`` interactuara con ellos 

<details>
    <summary>**Protocolos**:</summary>

    ```Swift

    protocol Interactor {
        func fetchAllUser() async throws -> [User]
        func fetchUser(at serialID: Int) async throws -> User
        func searchParents(at serialID: Int) async throws -> User
    }


    protocol View {
        @MainActor
        func loadUserList(userList: [User])
        @MainActor
        func showParents(user: User)
    }

    protocol Presenter {
        var view: View { get }
        var interactor: Interactor { get }
        
        func loadData()
        func selectedUser(user: User)
    }
    ```
</details>
<details>
    <summary>**Modelos**:</summary>

    ```Swift

        struct User: Decodable {
            let name: String
            let email: String
            let phone: String
            let age: Int
            let address: Address
            let acount: Account
        }

        struct Address: Decodable {
            let stret: String
            let cp: String
            let intNumber: Int
            let extNumber: Int
        }

        struct Account: Decodable {
            var numberAcount: Int
            var serialID: Int
        }
    ```
</details>
siguiendo el ejercicio, el ``presentador`` tendría la siguiente implementación
<details>
    <summary>**Presenter**:</summary>
```Swift
    final class PresenterImpl: Presenter {
        var view: View
        
        var interactor: Interactor
        var task: TaskCustom
        init(view: View, interactor: Interactor, task: TaskCustom) {
            self.view = view
            self.interactor = interactor
            self.task = task
        }
        
        func loadData() {
            task.run {
                let userList = try await self.interactor.fetchAllUser()
                await self.view.loadUserList(userList: userList)
            }
        }
        
        func selectedUser(user: User) {
            task.run {
                let user = try await self.interactor.searchParents(at: user.acount.serialID)
                await self.view.showParents(user: user)
            }
        }
    }
```
</details>

Si vemos la implementación del ``presenter``, vemos que lo que nos interesa probar es que al ejecutar la función ``loadData``, llama al ``interactor.fetchAllUser()`` esté nos retorna una lista una lista de usuarios ``[User]`` una vez obteniendo los datos se lo manda a la vista  ``await self.view.loadUserList(userList: userList)`` para hacer una prueba unitaria, nos interesa garantizar que esta unidad de código ``loadData()``
haga lo descrito antes, para ello hacemos uso de los test, pero antes de ello necesitamos generar `Mocks` y ``Spys``, empecemos primero por el ``spy`` 
