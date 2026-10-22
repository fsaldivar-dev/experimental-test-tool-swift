# Changelog

Todos los cambios notables de este proyecto se documentan aquí.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.1.0/) y el versionado [SemVer](https://semver.org/lang/es/).

## [2.0.0-beta.1] — 2026-10-22

Primera beta de Spock 2. Corre en macOS y Linux con SwiftPM (CI en ambos). Reescritura completa: los dobles de prueba dejan de resolverse en runtime con `Decodable` y pasan a generarse como **snapshots versionados** por `spock-gen`, a partir de anotaciones inertes en los tests.

### Añadido
- **`@Stubbed extension Tipo {}`**: genera `Tipo.stub(...)` con un parámetro por propiedad y valores por defecto deterministas y con sentido según el nombre y el tipo (`name` → `"Ana García"`, `email`, `createdAt` → fecha fija, `id` → `1`), más `Tipo.stubs(count:)`. `autoTree` genera los stubs de los tipos hijos. `--defaults plain` conserva los valores planos.
- **`@Mocking extension Protocolo {}`**: genera `ProtocoloMock` con la sintaxis `mock.whenCall(\.x).run/returns/throws` y `mock.verify(\.x).called()/called(times:)/called(with:)/called(where:)/history/last/count`. `throws` solo compila en métodos que lanzan.
- **`@Spied extension Impl {}`**: genera `ImplSpy`, un envoltorio que conforma a los protocolos del dominio, envuelve la implementación real, registra cada llamada y siempre delega.
- **`spock-gen`** (`generate` | `check` | `clean`): escribe un archivo por tipo en `Tests/<Target>/Generated/<Módulo>/<ruta>/{Stubs,Mocks,Spies}/`, reflejando la estructura del origen. `check` falla en CI si el dominio cambió y los snapshots no se regeneraron.
- Integración con `.xcodeproj`: `spock-gen` mantiene las referencias de archivo y una fase de build que regenera lo que falte (cache HIT ≈ 1 s).
- Runtime thread-safe para Swift 6: `MockedCall`, `MockedThrowingCall`, `SpiedCall` y el protocolo `SpockMock` con `whenCall` / `verify`.
- Documentación: guía de testing (Given/When/Then, `makeSUT`), comparativa con el ecosistema de test doubles de Swift y workflow de CI único.
- Soporte de Linux: SHA-256 propio sin CryptoKit y `FileWatcher` guardado por plataforma; CI corre build, test y `check` en macOS y Linux.

### Cambiado
- Mínimo Swift 6.1 (`swift-tools-version: 6.1`), solo Swift Package Manager.
- El property wrapper `@Stubbed<I, O>` de v1 se reemplaza por la sintaxis `whenCall` / `verify`.

### Eliminado
- API de v1: el protocolo `SpockDummy`, `.dummy()`, `SpockDummyGenerator`, `SpockDecoder` y los contenedores sintéticos (`SpockContainer`, `SpockSingleValueContainer`, `SpockUnkeyedContainer`).
- Soporte de CocoaPods (`SpockSwift.podspec`): Spock 2 requiere SwiftPM por las macros.

## [1.0.0] — 2022-08
Primera versión: dummies vía `Decodable` (`SpockDummy`, `.dummy()`) y mocks con property wrappers. Disponible en el tag `1.0.0`.
