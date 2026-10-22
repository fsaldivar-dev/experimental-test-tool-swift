# PRD — SpockRegression (record/replay de servicios)

> Estado: diseño temprano, **muchos supuestos abiertos** · Parte de la suite Spock
> Nombre del módulo por definir: `SpockRegression` · `SpockReplay` · `SpockContract` · `SpockService`

## De dónde viene este PRD

La plática arrancó en "regresiones" y evolucionó. La primera versión de este documento proponía golden master de valores; se descartó como eje. El dolor real que salió es otro: **el E2E está limitado por los servicios**. Si mockeas, el test es estable pero ya no es E2E (no probaste el contrato real). Si pegas al backend real, sí es E2E pero es flaky, lento y no controlas el estado. Este módulo ataca esa tensión.

(El golden master de valores queda como idea adyacente menor, sin prioridad; ver preguntas abiertas.)

## Problema

Elegir entre:
- **Mock**: determinista y rápido, pero mentiroso: un cambio del backend no se caza.
- **Real**: fiel pero inestable: red, estado incontrolable, cuentas y datos sembrados, no puedes forzar cada caso (un 500 a voluntad, por ejemplo).

## Objetivos

- Tests **deterministas** y **fieles al contrato real** del backend.
- **Señal de desfase** cuando el backend cambia el contrato (sin pegarle en cada corrida).
- Poder **forzar estados** que el backend real no da fácil (errores, vacíos, lentitud).
- **In-house**: interceptar en proceso, reproducir sin servidor ni JVM en CI.
- **Compatible con CLI** (`spock-gen`) y con formatos estándar para interoperar.

## No-objetivos

- **Servidor externo como dependencia dura** (WireMock/Prism solo como interop opcional, no requisito).
- **Postman como runtime**: sirve para versionar el catálogo de requests, pero no intercepta el tráfico de la app.
- Reemplazar un E2E real contra ambiente vivo para **flujos con estado profundo** entre varios servicios.
- Ser un simulador de backend completo.

## Decisión de arquitectura (acordada)

Apoyarse en **formatos**, no en servidor:
- **HAR** como formato de las grabaciones (estándar, JSON en git, interop con proxies, navegador, Postman, Replay).
- **OpenAPI** opcional como contrato para validar respuestas contra el schema.
- Motor **dentro del proceso** (intercepción de `URLSession` vía `URLProtocol`), manejado por `spock-gen`. En CI no corre ningún servidor.

## Capacidades (lista de deseos)

Núcleo:
- Interceptar `URLSession` **sin tocar producción**.
- **Grabar** la respuesta real a un HAR commiteado; **reproducir** determinista; modo **estricto** (falla si hay request no grabada).
- **Re-grabar contra vivo** por alcance (test/suite/global). El diff del re-grabado es la **señal de contrato**; `check` lo caza en CI.
- **Derivar estados** desde una grabación real: 500, lista vacía, pago rechazado, timeout, sin backend.
- **Escenarios con nombre** ("cuenta vacía", "pago declinado"), reutilizables entre unit test, snapshot y XCUITest.

Avanzado:
- **Secuencias con estado por endpoint** (login → token → data: el mismo endpoint responde distinto en llamadas sucesivas).
- **Matching normalizado**: ignorar timestamps, tokens, nonces, orden de query params.
- **Inyectar latencia y fallos** para probar loading/error deterministas.
- **Procedencia**: cada grabación sellada con cuándo y contra qué se grabó; aviso si está rancia.
- **Validación opcional contra OpenAPI**.
- **Interop**: importar/exportar HAR; con WireMock/Prism si el equipo ya los usa.

## Diseño / API (boceto, muy preliminar)

```swift
import SpockReplay

@Test(.tags(.integration), .scenario("cuenta-vacia"))
func emptyAccountShowsPlaceholder() async throws {
    // intercepta URLSession, reproduce el HAR del escenario "cuenta-vacia"
    let vm = AccountViewModel()
    await vm.load()
    #expect(vm.state == .empty)
}
```

```bash
spock-gen replay record --scope test --against staging   # graba contra vivo
spock-gen replay check                                     # falla si el contrato cambió y no re-grabaste
```

## Dependencias y relación con otras suites

- **SpockMock**: la respuesta grabada alimenta los dobles; el mock deja de ser una mentira escrita a mano y pasa a ser una respuesta real congelada.
- **SpockSnapshot**: un escenario de servicios lleva la UI a un estado concreto para snapshotearla.
- Infra `spock-gen` (record/check) y formatos HAR/OpenAPI.

## Supuestos y preguntas abiertas (aún muchos)

- **Secuencias con estado**: cómo modelarlas sin volverse un simulador de backend. ¿Máquina de estados declarativa por endpoint? ¿Cuántas respuestas en orden?
- **Matching normalizado**: dónde va la línea entre "ruido a ignorar" y "cambio real a cazar". Config por defecto vs por request.
- **Derivación de estados**: ¿mutaciones declarativas del HAR, transformaciones en código, o se graban a mano?
- **OpenAPI**: ¿validación en el MVP o fase 2? ¿Y si el backend no tiene spec?
- **Dónde viven los fixtures**: ¿`Generated/`, un `Fixtures/` aparte, junto al test?
- **Auth y secretos**: cómo grabar sin filtrar tokens reales al repo (redacción al grabar).
- **Nombre del módulo** y si el golden-master de valores sigue como idea aparte.
- **Plataforma**: in-process `URLProtocol` funciona en macOS y Linux; la parte de XCUITest sería Apple-only.
