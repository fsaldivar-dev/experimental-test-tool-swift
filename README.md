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

Para resolver estos problemas de raíz, **SpockSwift 2** redefine por completo la estrategia: **abandonamos los trucos de runtime con `Decodable` y adoptamos una arquitectura híbrida de Prebuild Tool + Macros de Swift**.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ARQUITECTURA DE SPOCK 2                               │
├─────────────────────────────────────┬───────────────────────────────────────┤
│ En tus Tests (Solo lo que necesitas)│ Generado Automáticamente (Stubs)      │
├─────────────────────────────────────┼───────────────────────────────────────┤
│ @Stub                               │ extension User {                      │
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
   Si `User` contiene a `Pet`, y `Pet` contiene a `Breed`, anotar `@Stub extension User {}` detecta todo el árbol y genera los stubs de los hijos automáticamente para que `.stub()` se encadene solo.
4. **Deduplicación Consciente del Archivo Fuente:**
   Si `@Stub extension User` se declara en dos archivos de prueba diferentes, el generador sabe qué archivo lo originó y evita generar extensiones duplicadas (*"invalid redeclaration"*).
5. **Caché Inteligente Incremental (SHA256):**
   Si los modelos no cambian, el prebuild no reescribe nada en disco y toma **< 5 ms**. Si un modelo cambia en producción, actualiza la firma del stub automáticamente.
6. **Modernización de `SpockMock` para Swift 6:**
   Mocks thread-safe protegidos contra data races, preparados para concurrencia estricta y Swift Testing (`@Test` / `#expect`).

---

## 🛠️ 4. Uso de SpockSwift 2

### En tu `Package.swift` (Target de Tests)

Conecta el plugin de compilación automática en tu target de pruebas:

```swift
// swift-tools-version: 6.0
.testTarget(
    name: "MyFeatureTests",
    dependencies: [
        "MyFeature",
        .product(name: "SpockSwift", package: "experimental-test-tool-swift")
    ],
    plugins: [
        .plugin(name: "SpockPlugin", package: "experimental-test-tool-swift")
    ]
)
```

### En tus archivos de Test

Simplemente declara qué modelos necesitas en tu archivo de prueba con `@Stub`:

```swift
import Testing
import SpockSwift
@testable import MyFeature

// 1. Declaras qué stubs deseas para tu suite de pruebas:
@Stub
extension User {}

@Suite("User Tests")
struct UserTests {
    @Test("Prueba con stub por defecto")
    func testDefault() {
        // Generado automáticamente con .stub(...) y autoTree para todos sus hijos:
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

### Ejecución por Línea de Comandos (`spock-gen` CLI)

También puedes usar `spock-gen` de forma manual o en un Build Phase de Xcode (`.xcodeproj`):

```bash
swift run spock-gen \
  --sources Sources/ \
  --tests Tests/ \
  --output Tests/Generated/Stubs.generated.swift \
  --cache .spock-cache.json
```

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
