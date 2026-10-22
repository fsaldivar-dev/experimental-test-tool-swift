# PRD — SpockMock

> Estado: **entregado** (2.0.0-beta.1) · Parte de la suite Spock

## Problema

Swift no tiene reflexión en runtime, así que los dobles de prueba se escriben a mano (mucho boilerplate por método) o se generan. Las opciones de generación o anotan el código de producción (`// @mockable`, `#if MOCKING`) o regeneran en cada build metiendo swift-syntax en el grafo de tests. Y no hay un estándar para fixtures tipados de structs.

## Objetivos

- Declarar los dobles **en los tests**, sobre una extensión vacía, sin tocar el dominio.
- Generar **stubs** de datos, **mocks** de protocolos y **espías** de implementaciones reales desde una sola herramienta.
- Salida **versionada** (snapshots), sin build-tool plugin en el grafo de tests.
- Una sola sintaxis para programar y verificar, pensada para Swift 6 y Swift Testing.

## No-objetivos

- Mocks de protocolos **genéricos** o con `associatedtype` (un mock tendría que guardar un `T` desconocido → API llena de `Any`).
- **Mocks parciales de clases** ("llama al real salvo este método"): el espía siempre delega, por diseño.
- **DSL de matchers** por rango y **verificación en orden** entre varios mocks (solo si un caso real lo pide).
- Fixtures con datos aleatorios o localizados (los valores son fijos y deterministas a propósito).

## Requisitos funcionales (entregados)

- `@Stubbed extension Tipo {}` → `Tipo.stub(...)` con valores por defecto deterministas por nombre y tipo, `Tipo.stubs(count:)`, y autoTree para los hijos. `--defaults plain` para valores planos.
- `@Mocking extension Protocolo {}` → `ProtocoloMock` con `whenCall(\.x).run/returns/throws` y `verify(\.x).called()/called(times:)/called(with:)/called(where:)/history/last/count`. `throws` solo en métodos que lanzan (tipos distintos en compilación).
- `@Spied extension Impl {}` → `ImplSpy` que conforma a los protocolos del dominio, envuelve la implementación real, registra y siempre delega.
- `spock-gen generate | check | clean`; salida en `Tests/<Target>/Generated/<Módulo>/<ruta>/{Stubs,Mocks,Spies}/`, commiteada.
- Integración con `.xcodeproj` (fase que regenera lo que falte). macOS y Linux.

## Diseño / API

Entregado y documentado en el [README](../../README.md) y [AGENTS.md](../../AGENTS.md). Runtime en `Sources/SpockSwift`, generador en `Sources/SpockGenCore`.

## Backlog (futuro, no bloqueante)

- **Validación en un proyecto real** (portón para dejar el beta).
- Distribuir `spock-gen` como **binario precompilado** (artifactbundle): primera corrida rápida y CI más corto.
- Explorar genéricos / `associatedtype` por una vía que no llene el API de `Any`.
- `verifyInOrder` y matchers por rango, si la demanda aparece.
- Reestructurar como módulo `SpockMock` bajo el paraguas (ver [overview](00-overview.md)).

## Riesgos y preguntas abiertas

- **Bus factor de uno** y sin adopción externa aún.
- El `.xcodeproj` se edita por texto; frágil ante formatos nuevos de Xcode (hoy cubierto por tests).
- ¿El rename a `SpockMock` entra en la ventana de beta?
