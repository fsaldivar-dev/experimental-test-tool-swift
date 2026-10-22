# SpockSwift 2 — guía para agentes de IA

Referencia densa para escribir tests con SpockSwift 2. Copiable a `AGENTS.md`, `CLAUDE.md` o reglas de Cursor del proyecto que la use. El README es la versión larga; esto es lo mínimo.

## Qué es

Genera dobles de prueba (stubs, mocks, espías) como archivos versionados. Anotas en los **tests**, nunca en el dominio. `spock-gen` lee el dominio y escribe un archivo por tipo en `Tests/<Target>/Generated/`, que se commitea. Swift 6.1+, solo SwiftPM.

## Instalar (una vez)

En el `.testTarget` del `Package.swift`, sin `plugins:`:

```swift
.product(name: "SpockSwift", package: "experimental-test-tool-swift")
```

## Flujo: anotar → generar → usar

1. En un archivo de tests, anota una **extensión vacía** con lo que necesitas:

```swift
import Testing
import SpockSwift
@testable import MyFeature

@Stubbed extension User {}                    // doble de datos
@Mocking extension UserRepositoryProtocol {}  // mock de protocolo
@Spied   extension InMemoryUserRepository {}  // espía de una impl real
```

2. Genera (y commitea `Generated/`). Con layout SwiftPM:

```bash
swift run spock-gen --sources Sources --tests Tests
```

3. En CI, falla si el dominio cambió y nadie regeneró:

```bash
swift run spock-gen check --sources Sources --tests Tests
```

Regla: después de cambiar el dominio (añadir un campo, un método, un protocolo) o una anotación, vuelve a correr `spock-gen` y commitea el diff de `Generated/`.

## Qué obtienes de cada anotación

**`@Stubbed extension User {}`** → `User.stub(...)` y `User.stubs(count:)`.
Un parámetro por propiedad con valor por defecto; los hijos del dominio se encadenan solos (autoTree).

```swift
let u = User.stub()                                  // valores por defecto
let v = User.stub(name: "Ana", pet: .stub(name: "Fido"))
let list = User.stubs(count: 3)                      // ids e índices distintos
```

**`@Mocking extension UserRepositoryProtocol {}`** → `UserRepositoryMock()` (se quita el sufijo `Protocol`).

```swift
let repo = UserRepositoryMock()
repo.whenCall(\.fetchUser).returns(.stub(name: "Ana"))     // valor fijo
repo.whenCall(\.fetchUser).returns { id in .stub(id: id) } // según parámetros
repo.whenCall(\.save).throws(MyError())                    // solo en métodos `throws`
repo.whenCall(\.fetch).run { id, completion in completion(.success(.stub())) } // efecto / completion
// sin programar: devuelve .stub() para tipos del dominio, 0/""/false para primitivos
```

**`@Spied extension InMemoryUserRepository {}`** → `InMemoryUserRepositorySpy(real)`.
Envuelve la implementación real, registra y **siempre** delega. No tiene `whenCall`.

```swift
let spy = InMemoryUserRepositorySpy(InMemoryUserRepository(users: [.stub(id: 1)]))
_ = try await sut(repository: spy).load(id: 1)   // corre el código real
```

## Verificar (mocks y espías)

```swift
mock.verify(\.fetch).called()              // ¿se llamó?
mock.verify(\.fetch).called(times: 2)
mock.verify(\.fetch).called(with: 42)      // requiere Equatable
mock.verify(\.save).called(where: { $0.user.id == 10 })  // tuplas / predicado
mock.verify(\.save).last                   // últimos parámetros (tupla etiquetada si hay varios)
mock.verify(\.fetch).history               // todos, en orden
mock.verify(\.fetch).count
```

## Esqueleto de un test (makeSUT + Given/When/Then)

```swift
@Suite("UserService")
struct UserServiceTests {
    private func makeSUT() -> (sut: UserService, repo: UserRepositoryMock) {
        let repo = UserRepositoryMock()
        return (UserService(repository: repo), repo)
    }

    @Test("formatea el nombre del usuario")
    func displayName() async throws {
        // Given
        let (sut, repo) = makeSUT()
        repo.whenCall(\.fetchUser).returns(.stub(name: "Ana", role: .admin))
        // When
        let name = try await sut.getUserDisplayName(id: 42)
        // Then
        #expect(name == "Ana (admin)")
        #expect(repo.verify(\.fetchUser).called(with: 42))
    }
}
```

## Límites (no intentar)

- **Sin genéricos ni `associatedtype`** en mocks y espías: métodos genéricos quedan con `fatalError`; protocolos con `associatedtype`/`init`/`subscript` se omiten. No los anotes esperando un mock.
- Los stubs necesitan **init memberwise accesible**: un struct con init propio o campos `private` no genera un `.stub()` compilable.
- `.throws` solo existe en métodos que lanzan; programarlo en uno que no lanza no compila.
- Un espía **nunca stubbea**: si necesitas "devuelve X en vez del real", usa un mock, no `@Spied`.
- No edites a mano los archivos de `Generated/`: la siguiente corrida los reescribe.
- `@Stubbed`/`@Mocking` van sobre `extension` (o un `struct`/`class` declarado en tests); no sobre el tipo de producción.

## Comandos

| Acción | Comando |
| --- | --- |
| Generar | `swift run spock-gen --sources Sources --tests Tests` |
| Verificar desfase (CI) | `swift run spock-gen check --sources Sources --tests Tests` |
| Borrar lo generado | `swift run spock-gen clean --sources Sources --tests Tests` |
| Valores planos (`dummy_`/0) | añade `--defaults plain` |
| Módulos con nombre propio | `--sources App=ruta --tests AppTests=ruta` |

En Xcode (`.xcodeproj`), `spock-gen` mantiene una fase de build que regenera lo que falte; abre el **workspace**, no el `Package.swift`.
