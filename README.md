# 🖖 SpockSwift 2

<img width="640" alt="SpockSwift Banner" src="https://user-images.githubusercontent.com/16517868/183414396-108611c1-8585-4ce5-8b4f-088ea4d15f04.png">

[![GitHub issues](https://img.shields.io/github/issues/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/issues)
[![GitHub stars](https://img.shields.io/github/stars/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/stargazers)
[![GitHub license](https://img.shields.io/github/license/fsaldivar-dev/experimental-test-tool-swift?style=for-the-badge)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/blob/main/LICENSE.md)
![Swift Version](https://img.shields.io/badge/Swift-6.1+-orange?style=for-the-badge&logo=swift)
[![CI](https://github.com/fsaldivar-dev/experimental-test-tool-swift/actions/workflows/ci.yml/badge.svg?branch=feat/spock-2)](https://github.com/fsaldivar-dev/experimental-test-tool-swift/actions/workflows/ci.yml)
![Estado](https://img.shields.io/badge/estado-beta-yellow?style=for-the-badge)

> ⚠️ **Beta.** El diseño está probado (91 tests, CI en verde), pero la madurez todavía no: hoy funciona en **macOS con Swift Package Manager**, lo mantiene una sola persona y aún no se ha usado fuera de este repositorio. No compila en Linux por ahora. Lee los [límites](AGENTS.md#l%C3%ADmites-no-intentar) antes de adoptarla en algo crítico.

Dobles de prueba para Swift inspirados en **Spock** (Java/Groovy): declaras en tus tests qué necesitas con una anotación, y `spock-gen` escribe los **stubs**, **mocks** y **espías** como archivos versionados junto a los tests. Tu dominio no cambia, tus tests compilan sin build-tool plugins, y la sintaxis es la misma para programar y verificar:

```swift
@Stubbed extension User {}                 // User.stub(name: "Ana")
@Mocking extension UserRepositoryProtocol {} // UserRepositoryMock()
@Spied   extension InMemoryUserRepository {} // InMemoryUserRepositorySpy(real)

repo.whenCall(\.fetchUser).returns(.stub(name: "Ana"))
#expect(repo.verify(\.fetchUser).called(with: 42))
```

---

> 🤖 **¿Eres un agente de IA?** Lee [AGENTS.md](AGENTS.md): una página densa con todo lo necesario para escribir tests con la librería, sin leer este README completo.

## Índice

1. [Quick Start](#-quick-start)
2. [Cómo funcionan los tests](#-cómo-funcionan-los-tests)
3. [Por qué SpockSwift 2 y no otra librería](#-por-qué-spockswift-2-y-no-otra-librería)
4. [Cómo escribir un test](#-cómo-escribir-un-test): Given / When / Then, `makeSUT`, elegir el doble, verificar, Swift Testing
5. [Referencia](#-referencia): `@Stubbed`, `@Mocking`, `@Spied`, `spock-gen`, Xcode
6. [De v1.0.0 a Spock 2](#-de-v100-a-spock-2)

---

## ⚡ Quick Start

Cinco minutos: instalar, anotar, generar, escribir un test y correrlo.

**1. Dependencia** en el target de tests de tu `Package.swift` (Swift 6.1+). Sin `plugins:`: no hay build-tool plugin, solo la librería, que trae las macros marcador.

```swift
.testTarget(
    name: "MyFeatureTests",
    dependencies: [
        "MyFeature",
        .product(name: "SpockSwift", package: "experimental-test-tool-swift")
    ]
)
```

**2. Anota en tus tests** qué dobles necesitas. El dominio no se toca.

```swift
// Tests/MyFeatureTests/UserServiceTests.swift
import Testing
import SpockSwift
@testable import MyFeature

@Stubbed extension User {}                   // User.stub(...) con autoTree para sus hijos
@Mocking extension UserRepositoryProtocol {} // UserRepositoryMock con whenCall / verify
```

**3. Genera** una vez. Con la convención de SwiftPM basta con esto:

```bash
swift run spock-gen --sources Sources --tests Tests
```

Aparece `Tests/MyFeatureTests/Generated/` con un archivo por tipo, reflejando la carpeta de origen. Commitéala.

**4. Escribe el test** con el sistema bajo prueba, sus dobles y tres bloques: Given, When, Then.

```swift
@Suite("UserService")
struct UserServiceTests {

    private func makeSUT() -> (sut: UserService, repo: UserRepositoryMock) {
        let repo = UserRepositoryMock()
        return (UserService(repository: repo), repo)
    }

    @Test("Devuelve el nombre formateado del usuario que entrega el repositorio")
    func displayName() async throws {
        // Given
        let (sut, repo) = makeSUT()
        repo.whenCall(\.fetchUser).returns(.stub(name: "Jhonatan", role: .admin))

        // When
        let displayName = try await sut.getUserDisplayName(id: 42)

        // Then
        #expect(displayName == "Jhonatan (admin)")
        #expect(repo.verify(\.fetchUser).called(with: 42))
    }
}
```

**5. Corre.**

```bash
swift test
```

El `Example/` del repositorio es exactamente esto, con un dominio de usuarios, y se corre con `swift test --filter Example`.

---

## 🧪 Cómo funcionan los tests

Los dobles son **snapshots versionados**, no código que se regenera en cada build.

| Momento | Qué pasa |
| --- | --- |
| Escribes `@Stubbed`, `@Mocking` o `@Spied` sobre una extensión vacía en tests | Nada todavía: la macro expande a nada, solo marca la intención |
| Corres `spock-gen` | Lee el dominio con swift-syntax, resuelve el árbol de tipos y escribe un archivo por tipo en `Generated/` |
| Compilas y corres los tests | El target de tests compila `Generated/` como cualquier otra carpeta. Sin build-tool plugin ni generador en el grafo de tests; solo el compiler plugin de las macros, resuelto con los binarios precompilados de swift-syntax (Swift 6.1.1 y Xcode 16.4 en adelante) |
| Cambia el dominio | `spock-gen check` lo detecta en CI; `spock-gen` lo regenera, y el diff del PR muestra qué firma cambió |

La salida refleja la estructura del módulo de origen:

```text
Tests/MyFeatureTests/Generated/
└── MyFeature/
    └── Data/
        ├── Entities/
        │   └── Stubs/
        │       ├── User+Stub.swift
        │       └── Pet+Stub.swift
        └── Services/
            ├── Mocks/
            │   └── UserRepositoryProtocol+Mock.swift
            └── Spies/
                └── InMemoryUserRepository+Spy.swift
```

**Dos cosas que se llaman plugin.** Un *build-tool plugin* de SwiftPM (`plugins:` en `Package.swift`) corre un ejecutable en cada build y mete sus dependencias en el grafo del target; SpockSwift no usa ninguno. Un *compiler plugin* de macros es el target que el compilador carga para expandir `@Stubbed`, `@Mocking` y `@Spied`; ese sí existe, pero las macros expanden a nada y SwiftPM lo resuelve con los binarios precompilados de swift-syntax. La fase de script de Xcode tampoco es un plugin: es un Run Script.

**Por qué un generador y no solo macros.** Una macro adjunta solo ve la declaración donde está escrita. Sobre `extension User {}` no ve las propiedades de `User`, y sobre `extension Interface {}` no ve los requisitos del protocolo. La única forma de leer el dominio desde los tests sin anotar el dominio es un generador. Y la única forma de que ese generador no cueste en cada build es versionar su salida.

**En CI**, un paso que falle si los stubs quedaron desfasados:

```bash
swift run spock-gen check --sources Sources --tests Tests
```

Sale con código 1 y lista los archivos faltantes, desfasados o huérfanos, con el comando exacto para regenerar.

**En Xcode** con un `.xcodeproj`, `spock-gen` mantiene el proyecto sincronizado y añade una fase que regenera lo que falte en cada build; con todo al día cuesta alrededor de un segundo. Detalles en la [referencia de Xcode](#xcode).

---

## 🔭 Por qué SpockSwift 2 y no otra librería

Investigamos el ecosistema de dobles de prueba para Swift a octubre de 2026: generadores de código, librerías de macros, helpers de runtime y generadores de fixtures. El informe completo, con fuentes y fechas, está en [docs/Comparativa de test doubles en Swift.md](<docs/Comparativa de test doubles en Swift.md>). Esto es el resumen.

**La restricción que ordena todo el mapa es del compilador.** Una macro adjunta solo recibe la declaración donde está escrita ([SE-0389](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md)). Por eso ninguna librería de macros puede generar un mock desde `@Mockable extension Repo {}` en tu target de tests: todas obligan a anotar el protocolo de producción y a gatear la expansión con `#if MOCKING` o `#if DEBUG`, y todas meten swift-syntax en el grafo del módulo principal, que Point-Free midió en unos 20 segundos en debug y más de 4 minutos en release ([Point-Free](https://www.pointfree.co/blog/posts/171-mitigating-swiftsyntax-build-times)). "Anotar en tests y generar desde el dominio" solo lo puede hacer un generador. La pregunta pasa a ser dónde corre y dónde vive su salida: los generadores existentes responden "en cada build, en derived data" o "en producción, con un marcador"; SpockSwift responde "una vez, en git, con un `check`", que es la misma respuesta que swift-snapshot-testing dio para las imágenes.

| Herramienta | Enfoque | Qué genera | ¿Anota producción? | swift-syntax en tus builds | Salida | Estado (2026-10) |
| --- | --- | --- | --- | --- | --- | --- |
| **SpockSwift 2** | generador CLI + macros marcador | stubs de structs con autoTree y valores deterministas con sentido, `stubs(count:)`, mocks de protocolos, espías delegantes | no, `extension X {}` en tests | solo el plugin de macros, con prebuilts | un archivo por tipo en `Generated/`, commiteado, `check` en CI | sin release, un mantenedor |
| Mockolo | generador CLI | mocks de protocolos | sí, `/// @mockable` | no (binario) | un archivo, derived data o ruta | 2.7.0, activo |
| Cuckoo | build-tool plugin | mocks de protocolos y clases, espías de clases | no, `Cuckoofile.toml` | sí, en cada build limpio, sin caché | `GeneratedMocks.swift` en derived data | 2.4.0; issue abierto con modo Swift 6 |
| Sourcery + AutoMockable | generador CLI | mocks de protocolos | sí, `// sourcery: AutoMockable` | no (binario) | ruta elegida, suele commitearse | binario 2.3.0 roto con tools 6.1+ |
| Mockable (Kolos65) | macro | mocks de protocolos, DSL `given/verify` | sí, `@Mockable` + `#if MOCKING` | sí, en producción | expansión en sitio | 0.6.4, activo, Linux y Wasm |
| swift-spyable | macro | spies estilo AutoMockable | sí, `@Spyable` | sí, techo `< 602` | expansión en sitio | 0.9.0, sin cambios desde 2025-07 |
| swift-mocking (Fetch) | macro | mocks de protocolos y actores, estáticos, subscripts | sí, `@Mocked` | sí, fijado a `600.0.0` | expansión en sitio | 0.4.1, activo |
| SwiftMocking (Cardona) | macro opcional + CLI | mocks de protocolos, `verifyInOrder` | opcional | si usas la macro | expansión o archivo | 0.8.4, activo |
| Mockingbird | build phase | mocks y parciales de protocolos y clases | no | no | gitignored | muerto desde 2022 |
| SwiftyMocky | Sourcery | mocks con DSL `Given/Verify` | sí | no | `Mock.generated.swift` | muerto desde 2022; rompe con Swift 6 |
| swift-fakable, Swifixture, LoremSwiftify | macro o CLI de fixtures | `fake()` / fixtures de structs | macro: sí; CLI: no | según el caso | expansión o archivo | 0 a 19 estrellas |
| SpryKit, swift-fakes | runtime | ayudas para fakes a mano | no | no | el fake lo escribes tú | activos |

**Lo que solo SpockSwift combina**, y cada competidor cede al menos una: producción sin anotar, cero build-tool plugin, stubs más mocks más espías desde un mismo generador, y salida versionada con verificación de desfase. Los fixtures tipados de structs sin anotar el modelo no los cubre ningún proyecto con adopción: las alternativas anotan el tipo de producción o usan `Decodable`, el mismo callejón del que salió nuestra v1.0.0.

**Cuándo elegir otra herramienta, y qué no vamos a imitar.** La sintaxis de SpockSwift son tres anotaciones, `whenCall` con tres verbos y `verify`; no va a crecer para cubrir cada caso de la tabla. Dónde otra herramienta te sirve mejor:

- **Mocks de protocolos genéricos o con `associatedtype`.** Un mock tendría que guardar un `T` que no conoce, y eso llena la API de `Any`. Los espías sí los reenvían, porque no guardan nada. Para mocks genéricos: Mockable, Mockolo o swift-mocking de Fetch.
- **Mocks parciales de clases**, "llama al real salvo este método". Aquí un espía nunca stubbea, a propósito: es la definición de Spock. Si lo necesitas, Cuckoo lo hace con `thenCallRealImplementation()`.
- **Verificación en orden entre varios mocks.** Los matchers ya están cubiertos con `called(where:)` y un closure; el orden entre mocks no, y solo se añadiría como una función si un caso real lo pide. smockable y SwiftMocking tienen `InOrder`.
- **Escala y Linux.** Mockolo nació para millones de líneas y se distribuye como binario para Linux. SpockSwift corre hoy en macOS; Linux es trabajo interno pendiente, no de API.
- **Madurez.** SpockSwift 2 no tiene release y lo mantiene una persona; Mockable, Cuckoo y Mockolo tienen años de releases y varios mantenedores.
- **Datos aleatorios o localizados.** Los valores de `.stub()` son fijos a propósito, para que un test dé lo mismo en cada corrida. Si quieres variedad o localización, LoremSwiftify y Fakery.

---

## ✍️ Cómo escribir un test

### Given / When / Then

También llamado Arrange / Act / Assert. Es la misma idea con dos nombres: un test se lee en tres bloques y cada bloque tiene un trabajo.

| Bloque | Qué va aquí | Con SpockSwift |
| --- | --- | --- |
| **Given** (Arrange) | El estado inicial: el SUT y sus dobles programados | `makeSUT()`, `.stub(...)`, `whenCall(\.x).returns(...)` |
| **When** (Act) | **Una sola** acción sobre el SUT | `try await sut.updateBio(...)` |
| **Then** (Assert) | Lo que debe ser cierto: resultado y colaboraciones | `#expect(...)`, `verify(\.x).called(with:)` |

Reglas que mantienen los tests legibles:

- Un `When` por test. Si necesitas dos acciones, son dos tests.
- El `Then` afirma sobre el resultado **y** sobre las interacciones que importan, no sobre todas. Si `saveUser` es el efecto que pruebas, verifícalo; no verifiques también `fetchUser` solo porque pasó.
- Programa en el `Given` solo lo que el test necesita. Un mock sin programar devuelve `.stub()` para tipos del dominio y valores por defecto para primitivos, así que la mayoría de los tests programan una sola llamada.
- Pon los comentarios `// Given`, `// When`, `// Then`. Cuestan tres líneas y hacen que cualquiera encuentre el `When` de un vistazo.

```swift
@Test("Actualiza el bio y guarda el usuario modificado")
func updateBio() async throws {
    // Given
    let (sut, repo) = makeSUT()
    repo.whenCall(\.fetchUser).returns { id in .stub(id: id, profile: .stub(bio: "Original")) }
    repo.whenCall(\.saveUser).returns(true)

    // When
    let success = try await sut.updateBio(id: 10, newBio: "Updated Bio")

    // Then
    #expect(success == true)
    let saved = try #require(repo.verify(\.saveUser).last)
    #expect(saved.profile.bio == "Updated Bio")
}
```

### `makeSUT`

El **SUT** (*system under test*) es el objeto que pruebas. `makeSUT` es una función privada de la suite que lo construye con sus dobles y devuelve todo con nombre:

```swift
private func makeSUT() -> (sut: UserService, repo: UserRepositoryMock) {
    let repo = UserRepositoryMock()
    let sut = UserService(repository: repo)
    return (sut, repo)
}
```

Y en cada test, `let (sut, repo) = makeSUT()`. Lo que gana:

- **Un solo lugar que cambia** cuando cambia el init del SUT. Si `UserService` recibe mañana un `Logger`, se añade en `makeSUT` y los tests no se tocan.
- **Los dobles salen a la vista** para el `Given` y el `Then`. La tupla etiquetada evita adivinar qué es cada cosa.
- **Parámetros con valores por defecto** para los casos que varían: `makeSUT(users: [.stub(id: 10)])`.
- **Aislamiento**: en Swift Testing cada `@Test` recibe una instancia nueva de la suite, y `makeSUT` construye dobles nuevos cada vez. Ningún test ve lo que programó otro.

Con un espía sobre la implementación real, `makeSUT` devuelve también el real, porque el `Then` suele comprobar que el real hizo el trabajo:

```swift
private func makeSUT(users: [User] = []) -> (sut: UserService, spy: InMemoryUserRepositorySpy, real: InMemoryUserRepository) {
    let real = InMemoryUserRepository(users: users)
    let spy = InMemoryUserRepositorySpy(real)
    return (UserService(repository: spy), spy, real)
}
```

### Elegir el doble

| Necesitas | Doble | Anotación | Lo obtienes |
| --- | --- | --- | --- |
| Un valor del dominio sin llenar veinte parámetros | **Stub** | `@Stubbed extension User {}` | `User.stub()`, `User.stub(name: "Ana")`; los hijos se encadenan solos |
| Reemplazar una dependencia y decidir qué responde | **Mock** | `@Mocking extension Repo {}` | `RepoMock()` con `whenCall` y `verify` |
| Usar la implementación real y saber cómo la usaron | **Spy** | `@Spied extension InMemoryRepo {}` | `InMemoryRepoSpy(real)` con `verify`, sin `whenCall` |

Una guía rápida: si el colaborador tiene una implementación de prueba honesta, en memoria por ejemplo, el espía da tests más fieles porque corre código real. Si no la tiene, o quieres forzar un error o un caso raro, el mock.

### Verificar interacciones

`verify(\.método)` devuelve la llamada registrada. Todo esto vale igual para mocks y espías:

| Pregunta | Expresión |
| --- | --- |
| ¿La llamaron? | `verify(\.fetch).called()` |
| ¿Exactamente N veces? | `verify(\.fetch).called(times: 2)` |
| ¿Con este parámetro? (requiere `Equatable`) | `verify(\.fetch).called(with: 42)` |
| ¿Alguna llamada cumple esto? (tuplas, predicados) | `verify(\.save).called(where: { $0.user.id == 10 })` |
| ¿Qué le pasaron la última vez? | `verify(\.save).last?.profile.bio` |
| ¿Todas las llamadas, en orden? | `verify(\.fetch).history == [1, 2, 3]` |
| ¿Cuántas? | `verify(\.fetch).count` |

Con dos o más parámetros, `last` y `history` entregan una tupla etiquetada con los nombres de la firma: `(user: User, note: String?)`.

### Swift Testing en dos minutos

El `Example` usa Swift Testing. Lo mínimo que hay que saber:

| Quieres | Escribe |
| --- | --- |
| Agrupar tests | `@Suite("UserService") struct UserServiceTests { … }`. Un `struct`: cada test recibe una instancia nueva |
| Un test | `@Test("lo que prueba") func nombre() async throws { … }`. `async` y `throws` según necesites |
| Afirmar | `#expect(a == b)`. Si falla, el mensaje muestra `a` y `b` evaluados |
| Desenvolver o parar | `let saved = try #require(repo.verify(\.save).last)`. Si es `nil`, el test falla ahí |
| Esperar un error | `await #expect(throws: Offline.self) { try await sut.load() }`, o `throws: UserNotFound(id: 99)` si el error es `Equatable` |
| Un test por caso | `@Test("…", arguments: [UserRole.admin, .member, .guest]) func f(role: UserRole)` |
| Saltar o acotar | `@Test(.disabled("pendiente"))`, `@Test(.tags(.slow))`, `@Test(.timeLimit(.minutes(1)))` |

Si usas XCTest, todo lo anterior funciona igual: `XCTestCase`, `XCTAssertEqual`, `XCTUnwrap`, `XCTAssertThrowsError`. Los dobles no dependen del framework. Los tests del runtime en `Tests/SpockSwiftTests` están en XCTest y los del generador en Swift Testing, por si quieres comparar.

---

## 📚 Referencia

### `@Stubbed`

```swift
@Stubbed
extension User {}

let user = User.stub()                                       // valores por defecto
let custom = User.stub(name: "Francisco", pet: .stub(name: "Firulais"))
```

- Genera `static func stub(...)` con un parámetro por propiedad y un valor por defecto **determinista y con sentido**, elegido por el nombre y el tipo: `name` → `"Ana García"`, `email` → `"ana.garcia@example.com"`, `phone`, `city`, `bio`, `avatarURL`, `createdAt` → una fecha fija, `id` → `1` o un `UUID` fijo, `age` → `30`, `count` → `3`, `price` → `9.99`, `isActive` → `true`; sin regla, `"dummy_<nombre>"`, `0` o `false`. Enums usan el primer caso, opcionales `nil`, colecciones vacías y tipos del dominio `.stub()`. Las reglas van por palabra (`userId`, `avatarURL`), no por substring: `named` no es `name`. Con `--defaults plain` vuelves a los valores planos de v2.0.
- Genera también `static func stubs(count:)`: una lista con identidad distinta, los identificadores incrementan y los textos llevan el índice (`"Ana García 1"`, `"ana.garcia2@example.com"`).
- **autoTree**: si `User` contiene `Profile` y `Profile` contiene `Pet`, anotar `User` genera los tres.
- Un modelo del dominio usado con `.stub()` en un test se genera aunque no lo anotes. Un struct declarado en el propio archivo de tests necesita `@Stubbed` explícito.
- Si una propiedad tiene valor por defecto en el modelo, se respeta.
- Los stubs usan el init memberwise: un struct con init propio o propiedades `private` necesita que ese init sea accesible desde tests.

### `@Mocking`

```swift
@Mocking
extension UserRepositoryProtocol {}

let repo = UserRepositoryMock()
```

Genera `<Protocolo>Mock` (sin el sufijo `Protocol`) con una llamada mockeada por requisito, lista para programar y verificar:

| Verbo | Qué hace | Disponible en |
| --- | --- | --- |
| `whenCall(\.x).run { params in … }` | efecto en cada invocación: disparar un completion, mutar estado | todos los métodos |
| `whenCall(\.x).returns(valor)` / `.returns { params in … }` | el valor que devuelve | métodos con retorno |
| `whenCall(\.x).throws(error)` / `.throws { params in … }` | el error que lanza (`nil` deja pasar a `returns`) | solo métodos `throws` |

Los verbos se encadenan y se ejecutan en ese orden: `run`, luego `throws`, luego `returns`.

```swift
// Completion handlers: el closure llega como parámetro
repo.whenCall(\.fetch).run { id, completion in completion(.success(.stub(id: id))) }

// O guárdalo y dispáralo cuando el test decida
sut.start()
repo.verify(\.observe).last?(.started)
```

Cómo se mapea cada firma: cero parámetros usan `()`, uno su tipo, dos o más una tupla etiquetada `(id: Int, note: String?)`. Métodos `throws` reciben un `MockedThrowingCall`, el resto un `MockedCall`, por lo que programar `throws` en un método que no lanza no compila. Sin nada programado, el método devuelve `.stub()` para tipos del dominio y el valor por defecto para primitivos.

Los tipos que el protocolo devuelve reciben su `.stub()` automáticamente, los requisitos de los protocolos padre del dominio se incluyen, y los closures sin `@escaping` llegan a `run` pero no quedan en `history`. Métodos genéricos quedan con `fatalError`; protocolos con `associatedtype`, `init` o `subscript` se omiten con un aviso.

### `@Spied`

```swift
@Spied
extension InMemoryUserRepository {}

let spy = InMemoryUserRepositorySpy(InMemoryUserRepository(users: [.stub(id: 10)]))
```

Genera `<Tipo>Spy`: conforma a los protocolos del dominio a los que el tipo conforma, también los declarados en extensiones y sus padres, guarda la implementación real en `var inMemoryUserRepository`, registra cada llamada y **siempre** delega. Solo espía, no mockea: no tiene `whenCall`, y el tipo `SpiedCall` lo impide por construcción.

```swift
final class InMemoryUserRepositorySpy: UserRepositoryProtocol, SpockMock, @unchecked Sendable {
    struct Calls {
        let fetchUser = SpiedCall<Int>()
        let saveUser = SpiedCall<User>()
    }
    let calls = Calls()
    var inMemoryUserRepository: InMemoryUserRepository

    init(_ inMemoryUserRepository: InMemoryUserRepository) { … }

    func fetchUser(id: Int) async throws -> User {
        calls.fetchUser.record(id)
        return try await inMemoryUserRepository.fetchUser(id: id)
    }
}
```

Si el tipo no conforma a ningún protocolo conocido, espía todos sus métodos no privados sin declarar conformancia. Los parámetros `inout` se registran como copia y se reenvían con `&`; los closures sin `@escaping` quedan como `Void` en el registro; los métodos genéricos y los variádicos se omiten con un aviso en el archivo.

### `spock-gen`

```text
spock-gen [generate | check | clean | daemon start|stop|status] [opciones]

  --sources <Módulo=dir | dir> ...  Raíces de los módulos de producción
  --tests   <Módulo=dir | dir> ...  Raíces de los módulos de tests con las anotaciones
  --output  <dir>                   Carpeta de salida (por defecto <primer tests dir>/Generated)
  --cache   <ruta>                  Manifiesto de caché (por defecto .spock-cache.json)
  --no-xcode                        No sincroniza el .xcodeproj cercano a la carpeta de salida
  --watch, -w                       Observa cambios y regenera al guardar
```

Un `dir` sin módulo toma el nombre de su último componente. Si el último componente es `Sources` o `Tests`, cada subcarpeta se registra como un módulo, que es la convención de SwiftPM. Para otra disposición, nómbralos: `--sources App=Example/Example --tests AppTests=Example/ExampleTests`.

- `generate` (por defecto) escribe lo que cambió, elimina lo huérfano y sincroniza el proyecto de Xcode si lo hay.
- `check` compara en memoria contra el disco y sale con 1 si hay desfase. Para CI y pre-commit.
- `clean` borra lo generado y la caché.
- `--watch` y `daemon` regeneran al guardar. Comodidad local, no infraestructura.

### Xcode

Con un `.xcodeproj`, `spock-gen` mantiene el proyecto sincronizado cuando lo encuentra cerca de la carpeta de salida: crea grupos que reflejan las carpetas de `Generated`, una referencia por archivo y una fase de script en el target de tests que declara esos archivos como outputs y corre `spock-gen` en cada build. Con todo al día la fase es una comprobación de hashes que termina en alrededor de un segundo; si borras la carpeta o un archivo, cambió el dominio o apareció una anotación nueva, regenera y actualiza el proyecto.

Un archivo que ya estaba referenciado compila en ese mismo build. Uno nuevo, que no existía al cargar el proyecto, compila en el siguiente, porque Xcode fija la lista de fuentes antes de ejecutar cualquier fase. Si borras desde el navegador de Xcode con "Move to Trash", Xcode quita también las referencias: la fase las restaura, y esa vez compila al segundo build.

**Qué verás en Build Phases del target de tests.** Todo esto lo escribe `spock-gen`; no hace falta tocarlo, y si lo tocas, la siguiente sincronización lo reescribe.

| Campo | Valor | Por qué |
| --- | --- | --- |
| Posición | primera fase, antes de Compile Sources | los archivos tienen que existir antes de compilar |
| Nombre | `Spock: sincronizar Generated` | |
| Shell | `/bin/sh` | |
| Script | `cd` a la raíz del paquete y `env -i … /usr/bin/swift run spock-gen --sources … --tests … --output …`, con el resultado y la duración en `.build/spock-phase.log` | el entorno limpio hace que SwiftPM comparta la caché de `.build` con la terminal en vez de recompilar el generador |
| Based on dependency analysis | desactivado | la fase corre en cada build; con todo al día termina en cerca de un segundo |
| Input Files | vacío | los inputs reales son el dominio y los tests, y los decide el manifiesto de caché |
| Output Files | un `$(SRCROOT)/…/Generated/…` por archivo generado, ordenados por ruta | así Xcode sabe que esos archivos salen de la fase y compila los que ya referencia |

Cuando aparece o desaparece un archivo generado, `spock-gen` actualiza la lista de Output Files, las referencias y los grupos en la misma corrida.

Lo que escribe en el `.pbxproj` lleva identificadores con prefijo `5B0C4E5F` y se reconstruye en cada sincronización. Desactívalo con `--no-xcode`. Si el target tiene `ENABLE_USER_SCRIPT_SANDBOXING = YES`, ponlo en `NO`: la fase necesita leer `Package.swift` y escribir fuera de sus outputs. El rastro de cada ejecución queda en `.build/spock-phase.log`. Abre el **workspace** del proyecto, no el `Package.swift`: al abrir el paquete, SwiftPM compila la carpeta tal cual está y no existe la fase.

---

## 🕰️ De v1.0.0 a Spock 2

### Cómo funcionaba SpockSwift v1.0.0

En su versión 1.0.0, SpockSwift abordó la falta de reflexión en Swift mediante dos componentes centrales.

**Dummies automáticos vía `Decodable` (`SpockDummy`).** La idea consistió en usar el motor nativo de `Decodable` de Swift a través de un decodificador sintético (`SpockDecoder`) para instanciar estructuras complejas sin tener que llenar 20 parámetros a mano:

```swift
// En v1: El modelo requería conformar SpockDummy
struct User: Codable, SpockDummy {
    let name: String
    var age: Int
    var profession: Profession
}

let user: User = try .dummy()
let customUser: User = try .dummy(with: .init(at: "name", with: "Francisco"))
```

**Mocks y spies mediante property wrappers (`@Stubbed` y `SpockMock`).** Permitía registrar llamadas, contar invocaciones y mockear retornos sin herramientas externas pesadas (como Cuckoo o Sourcery):

```swift
final class MockInteractor: Interactor, SpockMock {
    @Stubbed<(), [User]>
    var fetchAllUserAction

    func fetchAllUser() -> [User] {
        try? fetchAllUserAction.onCall(()) ?? []
    }
}

mockInteractor.fetchAllUserAction.whenRun { _ in expectedUsers }
presenter.loadData()
XCTAssert(mockInteractor.isInvoked(stub: { $0.fetchAllUserAction }))
```

### Diagnóstico: límites y dolores reales de v1.0.0

A pesar de ser un experimento ingenioso, la implementación basada en `Decodable` demostró severas limitaciones en proyectos de producción.

- **Contaminación de entidades de dominio.** Obligaba a que los modelos de producción conformaran `SpockDummy: Decodable`. Peor aún: si una entidad tiene propiedades no-Codable (closures, delegados, `Any`), Swift prohíbe que sea `Decodable` y el modelo no puede usarse con la librería.
- **Enums, UUIDs, Dates y URLs.** `SpockDecoder` inyectaba valores primitivos ciegos: `""` para strings y `0` para números. `Role(rawValue: "")` fallaba con `DecodingError.dataCorrupted` y hacía crashear la prueba. Lo mismo con `UUID(uuidString: "")` y `URL(string: "")`.
- **Strings mágicos sin tipado estático.** Sobreescribir un campo era `.init(at: "name", with: "Javi")`. Renombrar `name` a `fullName` no fallaba en compilación; fallaba silenciosamente en runtime.
- **Concurrencia y Swift 6.** `Spy` y `Stub` no tenían sincronización ni aislamiento a actores, y producían condiciones de carrera en `invokedCount += 1` dentro de `Task` concurrentes.

### Qué cambió en Spock 2

Spock 2 abandona los trucos de runtime con `Decodable` y adopta un generador (`spock-gen`) cuya salida se versiona como snapshots, más macros marcador inertes (`@Stubbed`, `@Mocking`, `@Spied`).

1. **Cero contaminación en producción.** Los modelos de dominio no llevan ningún protocolo, import ni anotación de testing.
2. **Sintaxis directa `.stub(...)`.** Extensiones nativas con parámetros con valores por defecto, tipados: renombrar un campo rompe en compilación.
3. **autoTree.** Si `User` contiene a `Pet`, y `Pet` contiene a `Breed`, anotar `User` genera los tres.
4. **Deduplicación consciente del archivo fuente.** Si `@Stubbed extension User` se declara en dos archivos de prueba, el generador sabe cuál lo originó y evita declaraciones duplicadas.
5. **Stubs, mocks y espías como snapshots versionados.** Un archivo por tipo en `Generated/`, dentro del target de tests. Los tests compilan sin build-tool plugins; `spock-gen check` detecta el desfase en CI.
6. **Mocks y espías para Swift 6.** `MockedCall` y `SpiedCall` son thread-safe, y la sintaxis `whenCall` / `verify` sustituye a los property wrappers.

---

## 📦 Migrar desde v1.0.0

La API de v1 (el protocolo `SpockDummy`, `.dummy()` y el decodificador `Decodable`) y el soporte de CocoaPods se **retiraron** en Spock 2. Spock 2 es solo Swift Package Manager y Swift 6.1+.

La v1.0.0 sigue disponible en su tag para quien la necesite:

```swift
dependencies: [
    .package(url: "https://github.com/fsaldivar-dev/experimental-test-tool-swift", exact: "1.0.0")
]
```

Para migrar a Spock 2, cambia los dobles de datos de `.dummy()` a `.stub()` generado:

| v1 | Spock 2 |
| --- | --- |
| `struct User: Codable, SpockDummy {}` | `struct User {}` (el dominio no lleva nada) y `@Stubbed extension User {}` en tests |
| `let user: User = try .dummy()` | `let user = User.stub()` |
| `.dummy(with: .init(at: "name", with: "Ana"))` | `User.stub(name: "Ana")` (tipado: renombrar el campo rompe en compilación) |
| Property wrappers `@Stubbed<I, O>` / `whenRun` / `isInvoked` | `@Mocking extension Repo {}`, `mock.whenCall(\.x).returns(...)`, `mock.verify(\.x).called()` |

El resto de la migración, cómo anotar y generar, está en el [Quick Start](#-quick-start).

## 👤 Autor y licencia

Creado por **Francisco Javier Saldivar** ([LinkedIn](https://www.linkedin.com/in/fsaldivar-dev))
Licenciado bajo **MIT License**.
