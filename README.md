# 🖖 SpockSwift (v1.0.0)

<img width="640" alt="SpockSwift Banner" src="https://user-images.githubusercontent.com/16517868/183414396-108611c1-8585-4ce5-8b4f-088ea4d15f04.png">

[![GitHub issues](https://img.shields.io/github/issues/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/issues)
[![GitHub stars](https://img.shields.io/github/stars/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/stargazers)
[![GitHub license](https://img.shields.io/github/license/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/blob/main/LICENSE.md)
![Swift Version](https://img.shields.io/badge/Swift-5.0+-orange?style=for-the-badge&logo=swift)
![Cocoapods](https://img.shields.io/cocoapods/v/SpockSwift?style=for-the-badge)

Librería para Swift inspirada en el framework **Spock** (de Java/Groovy) diseñada para agilizar y simplificar la creación de **Mocks, Dummies y Spies** mediante código declarativo y ligero.

---

## 📖 1. ¿Cómo funcionaba SpockSwift v1.0.0?

En su versión 1.0.0, SpockSwift abordó la falta de reflexión en Swift mediante dos componentes centrales:

### A. Dummies Automáticos vía `Decodable` (`SpockDummy`)
La idea consistió en usar el motor nativo de `Decodable` de Swift a través de un decodificador sintético (`SpockDecoder`) para instanciar estructuras complejas sin tener que llenar 20 parámetros a mano:

```swift
// En v1: El modelo requería conformar SpockDummy
struct User: Codable, SpockDummy {
    let name: String
    var age: Int
    var profession: Profession
}

// Generación con valores por defecto:
let user: User = try .dummy()

// Sobreescritura mediante strings:
let customUser: User = try .dummy(with: .init(at: "name", with: "Francisco"))
```

### B. Mocks y Spies mediante Property Wrappers (`@Stubbed` y `SpockMock`)
Permite registrar llamadas, contar invocaciones y mockear retornos sin herramientas externas pesadas (como Cuckoo o Sourcery):

```swift
final class MockInteractor: Interactor, SpockMock {
    @Stubbed<(), [User]>
    var fetchAllUserAction
    
    func fetchAllUser() -> [User] {
        try? fetchAllUserAction.onCall(()) ?? []
    }
}

// En el test:
mockInteractor.fetchAllUserAction.whenRun { _ in expectedUsers }
presenter.loadData()

XCTAssert(mockInteractor.isInvoked(stub: { $0.fetchAllUserAction }))
```

---

## 🛑 2. Diagnóstico Técnico: Límites y Dolores Reales de v1.0.0

A pesar de ser un experimento ingenioso, la implementación basada en `Decodable` demostró severas limitaciones en proyectos de producción:

### 💥 Dolor 1: Contaminación de Entidades de Dominio (Clean Architecture Roto)
* **El problema:** Obligaba a que tus modelos de negocio de producción (`struct User`, `struct Order`) conformaran `SpockDummy: Decodable`.
* **Consecuencia:** Contamina el dominio con protocolos de testing. Peor aún: si una entidad tiene propiedades no-Codable (closures como `() -> Void`, delegados o tipos `Any`), **Swift prohíbe que sea `Decodable`** y el modelo no puede usarse con la librería.

### 💥 Dolor 2: El Desastre de los Enums, UUIDs, Dates y URLs (Runtime Crashes)
* **El problema:** `SpockDecoder` inyecta valores primitivos ciegos: `""` para Strings y `0` para números.
* **El fallo:**
  ```swift
  enum Role: String, Codable { case admin = "ADMIN", client = "CLIENT" }
  ```
  Al decodificar `Role`, `SpockDecoder` le entregaba `""`. Swift ejecutaba `Role(rawValue: "")`, fallaba y lanzaba `DecodingError.dataCorrupted`, **haciendo crashear la prueba unitaria**.
  Lo mismo ocurría con `UUID(uuidString: "")` y `URL(string: "")`, que devolvían `nil` y abortaban la inicialización.

### 💥 Dolor 3: Strings Mágicos sin Tipado Estático
* Para sobreescribir un campo se usaban strings literales: `.init(at: "name", with: "Javi")`.
* Si en el modelo de producción se renombraba `name` a `fullName`, el test no fallaba en compilación; fallaba silenciosamente en runtime.

### 💥 Dolor 4: Concurrencia y Swift 6 Data Races
* Las clases `Spy` y `Stub` no contaban con sincronización por hilos ni aislamiento a actores. Al usarse dentro de `Task` asíncronos concurrentes, producían condiciones de carrera en `invokedCount += 1`.

---

## 🚀 3. La Evolución: Hacia SpockSwift 2 (`Spock 2`)

Para resolver estos problemas de raíz, **SpockSwift 2** redefine por completo la estrategia: **abandonamos los trucos de runtime con `Decodable` y adoptamos un generador (`spock-gen`) cuya salida se versiona como snapshots, más una macro marcador (`@Stubbed`)**.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ARQUITECTURA DE SPOCK 2                               │
├─────────────────────────────────────┬───────────────────────────────────────┤
│ En tus Tests (Solo lo que necesitas)│ Generated/…/Stubs (versionado)        │
├─────────────────────────────────────┼───────────────────────────────────────┤
│ @Stubbed                            │ extension User {                      │
│ extension User {}                   │     public static func stub(          │
│                                     │         name: String = "dummy_name",  │
│                                     │         pet: Pet = .stub()            │
│                                     │     ) -> User { ... }                 │
│                                     │ }                                     │
│                                     │ extension Pet {                       │
│                                     │     public static func stub(...)      │
│                                     │ }                                     │
└─────────────────────────────────────┴───────────────────────────────────────┘
```

### Pilares de Spock 2:

1. **Cero Contaminación en Producción:**
   Tus modelos de dominio en `Sources/` no llevan ningún protocolo, ningún import y ninguna anotación de testing.
2. **Sintaxis Directa `.stub(...)`:**
   Sin envoltorios innecesarios ni nombres largos. Extensiones nativas en Swift con parámetros con valores por defecto.
3. **Motor `autoTree` (Resolución Recursiva en Cascada):**
   Si `User` contiene a `Pet`, y `Pet` contiene a `Breed`, anotar `@Stubbed extension User {}` detecta todo el árbol y genera los stubs de los hijos automáticamente para que `.stub()` se encadene solo.
4. **Deduplicación Consciente del Archivo Fuente:**
   Si `@Stubbed extension User` se declara en dos archivos de prueba diferentes, el generador sabe qué archivo lo originó y evita generar extensiones duplicadas (*"invalid redeclaration"*).
5. **Stubs como snapshots versionados:**
   `spock-gen` escribe un archivo por modelo en `Generated/<Módulo>/<ruta>/Stubs/<Tipo>+Stub.swift`, dentro del target de tests, y se commitea. Los tests compilan sin plugins ni generación en build; `spock-gen check` detecta en CI si el dominio cambió y los stubs quedaron desfasados.
6. **Modernización de `SpockMock` para Swift 6:**
   Mocks thread-safe protegidos contra data races, preparados para concurrencia estricta y Swift Testing (`@Test` / `#expect`).

---

## 🛠️ 4. Uso de SpockSwift 2

Los stubs son **snapshots versionados**: `spock-gen` los escribe una vez en la carpeta `Generated` de tu target de tests, los commiteas, y los tests compilan sin plugins ni generación en build. Lo único que entra al grafo de tests es la macro `@Stubbed`, que SwiftPM resuelve con los binarios precompilados de swift-syntax.

### 1. Dependencia en `Package.swift` (Target de Tests)

```swift
// swift-tools-version: 6.1
.testTarget(
    name: "MyFeatureTests",
    dependencies: [
        "MyFeature",
        .product(name: "SpockSwift", package: "experimental-test-tool-swift")
    ]
)
```

Sin `plugins:`. En un `.xcodeproj`, `spock-gen` mantiene el proyecto sincronizado por ti cuando encuentra uno cerca de la carpeta de salida: crea grupos que reflejan las carpetas de `Generated`, una referencia por archivo y una fase de script en el target de tests que declara esos archivos como outputs y corre `spock-gen` en cada build. Con todo al día la fase es una comprobación de hashes que termina en milisegundos; si borras la carpeta o un archivo, cambió el dominio o apareció un `@Stubbed` o `@Mocking` nuevo, regenera y actualiza el proyecto. Un archivo que ya estaba referenciado compila en ese mismo build; uno nuevo, que no existía al cargar el proyecto, compila en el siguiente, porque Xcode fija la lista de fuentes antes de ejecutar cualquier fase.

Lo que escribe en el `.pbxproj` lleva identificadores con prefijo `5B0C4E5F` y se reconstruye en cada sincronización. Desactívalo con `--no-xcode`. Si el target tiene `ENABLE_USER_SCRIPT_SANDBOXING = YES`, ponlo en `NO`: la fase necesita leer `Package.swift` y escribir fuera de sus outputs. El rastro de cada ejecución queda en `.build/spock-phase.log`.

El `Example` del repositorio está configurado así.

### 2. Declara qué stubs necesitas

```swift
import Testing
import SpockSwift
@testable import MyFeature

// Declaras qué stubs quieres para tu suite; autoTree genera también los hijos (Pet, Breed, …):
@Stubbed
extension User {}

@Suite("User Tests")
struct UserTests {
    @Test("Prueba con stub por defecto")
    func testDefault() {
        let user = User.stub()
        #expect(!user.name.isEmpty)
        #expect(user.pet.name == "dummy_name")
    }

    @Test("Prueba con campos personalizados")
    func testCustom() {
        let user = User.stub(name: "Francisco", pet: .stub(name: "Firulais"))
        #expect(user.name == "Francisco")
        #expect(user.pet.name == "Firulais")
    }
}
```

Un modelo usado con `.stub()` sin anotar también se genera; `@Stubbed` deja la intención explícita.

### 3. Genera y versiona

```bash
swift run spock-gen --sources MyFeature=Sources/MyFeature --tests MyFeatureTests=Tests/MyFeatureTests
```

Con la convención de SwiftPM basta `spock-gen --sources Sources --tests Tests`: cada subcarpeta es un módulo. La salida refleja la estructura del módulo de origen:

```text
Tests/MyFeatureTests/Generated/
└── MyFeature/
    └── Data/
        └── Entities/
            └── Stubs/
                ├── User+Stub.swift
                └── Pet+Stub.swift
```

Commitea `Generated/`. Cada archivo lleva su origen en la cabecera, y el diff del PR muestra qué firma cambió cuando cambia el dominio.

### 4. Detecta desfases en CI

```bash
swift run spock-gen check --sources Sources --tests Tests
```

Sale con código 1 y lista los stubs faltantes, desfasados o huérfanos, con el comando exacto para regenerar. Úsalo en CI o en un hook de pre-commit.

### 5. Mocks de protocolos con `@Mocking`

El mismo generador lee los protocolos del dominio. Anota una extensión vacía y obtienes `<Protocolo>Mock`, una clase con una llamada mockeada por requisito que se programa con `whenCall` y se verifica con `verify`:

```swift
@Mocking
extension UserRepositoryProtocol {}

@Test func testDisplayName() async throws {
    let repo = UserRepositoryMock()
    repo.whenCall(\.fetchUser).returns(.stub(name: "Jhonatan", role: .admin))

    let name = try await UserService(repository: repo).getUserDisplayName(id: 42)

    #expect(name == "Jhonatan (admin)")
    #expect(repo.verify(\.fetchUser).called(with: 42))
}
```

Tres verbos para programar, que se encadenan:

| Verbo | Qué hace | Disponible en |
|---|---|---|
| `run { params in … }` | efecto en cada invocación: disparar un completion, mutar estado | todos los métodos |
| `returns(valor)` / `returns { params in … }` | el valor que devuelve | métodos con retorno |
| `throws(error)` / `throws { params in … }` | el error que lanza (`nil` deja pasar a `returns`) | solo métodos `throws` |

Y la verificación: `called()`, `called(times:)`, `called(with:)` cuando el parámetro es `Equatable`, `called(where:)` para tuplas, `history`, `last` y `count`.

```swift
// Completion handlers: el closure llega como parámetro
repo.whenCall(\.fetch).run { id, completion in completion(.success(.stub(id: id))) }

// O guárdalo y dispáralo cuando el test decida
sut.start()
repo.verify(\.observe).last?(.started)
```

Cómo se mapea cada firma: cero parámetros usan `()`, uno su tipo, dos o más una tupla etiquetada `(id: Int, note: String?)`. Métodos `throws` reciben un `MockedThrowingCall`, el resto un `MockedCall`, por lo que programar `throws` en un método que no lanza no compila. Sin nada programado, el método devuelve `.stub()` para tipos del dominio y el valor por defecto para primitivos.

El mock se escribe en `Generated/<Módulo>/<ruta>/Mocks/<Protocolo>+Mock.swift`. Los tipos que el protocolo devuelve reciben su `.stub()` automáticamente, los requisitos de los protocolos padre del dominio se incluyen, y los closures sin `@escaping` llegan a `run` pero no quedan en `history`. Métodos genéricos quedan con `fatalError`; protocolos con `associatedtype`, `init` o `subscript` se omiten con un aviso.

### Otros comandos

- `spock-gen clean`: elimina los stubs generados y la caché.
- `spock-gen --watch` o `spock-gen daemon start`: regenera al guardar. Comodidad local, no infraestructura.

---

## 📦 Instalación Legacy (v1.0.0)

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/fsaldivar-dev/experimental-test-tool-swift", from: "1.0.0")
]
```

### CocoaPods
```ruby
pod 'SpockSwift', '~> 1.0.0'
```

---

## 👤 Autor y Licencia

Creado por **Francisco Javier Saldivar** ([LinkedIn](https://www.linkedin.com/in/fsaldivar-dev))  
Licenciado bajo **MIT License**.
