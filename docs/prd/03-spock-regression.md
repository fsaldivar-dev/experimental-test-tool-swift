# PRD — SpockRegression

> Estado: diseño · Parte de la suite Spock

## Nota de alcance

"Regresión" no es un tipo de test con herramienta propia; es un **propósito**: fijar el comportamiento para que un cambio futuro no lo rompa en silencio. SpockRegression es el **motor de snapshots de Spock aplicado a valores y lógica no-UI** (golden master / characterization). Comparte mecanismo con [SpockSnapshot](02-spock-snapshot.md); la diferencia es que el artefacto es el **valor serializado**, no un árbol de UI.

`spock-gen check` de SpockMock ya es regresión de los dobles. Este módulo generaliza esa idea a cualquier salida.

## Problema

Para fijar la salida de una función pura, un `Codable`, una respuesta de API transformada o un reducer, hoy se escriben aserciones literales a mano (`#expect(result == "…")`) que son tediosas de actualizar y no muestran bien qué cambió. No hay un golden-master nativo, device-independent, con diff legible y re-record granular.

## Objetivos

- Capturar la salida de una función/valor como **golden file versionado**, revisable en el PR.
- Fallar con **diff de texto legible** cuando la salida cambia.
- **Re-grabado granular** (test / suite / global), igual que Snapshot.
- Determinista e independiente de plataforma (serialización canónica).

## No-objetivos

- UI (eso es SpockSnapshot).
- Píxeles o recursos visuales.
- Reemplazar aserciones puntuales donde una igualdad simple es más clara (`#expect(sum == 4)`).

## Requisitos funcionales

- `assertGolden(of: value)` → serializa el valor (JSON/`CustomStringConvertible`/`Codable`/dump estructural) a `Generated/Golden/<Suite>/<test>.txt` y compara.
- Serialización **canónica**: orden de claves estable, fechas/UUIDs normalizables, sin ruido no determinista.
- Primera corrida graba y falla (como snapshots), para que el CI no "pase por accidente".
- `spock-gen golden record --scope test|suite|all` y `check`.
- Estrategias de serialización conectables (JSON, texto, dump) por tipo.

## Diseño / API (boceto)

```swift
import SpockRegression

@Test(.tags(.regression))
func formatsInvoice() {
    let invoice = InvoiceFormatter.format(.stub(total: 100))   // SpockMock para el input
    assertGolden(of: invoice)                                  // golden file versionado
}
```

```bash
spock-gen golden record --scope suite InvoiceTests
spock-gen golden check
```

## Dependencias y relación con otras suites

- **SpockSnapshot**: mismo motor de dos fases; de hecho podrían compartir el `spock-gen` subcomando y diferenciarse por "estrategia" (árbol de UI vs valor). Decisión abierta: ¿un módulo con dos estrategias o dos módulos?
- **SpockMock** para construir los inputs deterministas.

## Riesgos y preguntas abiertas

- **Solapamiento con SpockSnapshot:** ¿vale la pena como módulo separado o es una estrategia de Snapshot? (El usuario pidió PRD propio; aquí queda la decisión documentada.)
- Normalización de valores no deterministas (fechas, ids) sin esconder regresiones reales.
- Solapamiento con swift-snapshot-testing (`.dump`): el diferencial es el DX unificado (record por capa/alcance, `check` en CI) y vivir en el paraguas.
