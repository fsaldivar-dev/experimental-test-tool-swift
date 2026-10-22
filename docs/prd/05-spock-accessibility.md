# PRD — SpockAccessibility

> Estado: diseño · Parte de la suite Spock

## Nota de alcance

Accesibilidad **no** se snapshotea: se **afirma**. SpockAccessibility son **reglas sobre el árbol de accesibilidad** que [SpockSnapshot](02-spock-snapshot.md) ya captura. Puede correr por su cuenta (afirmar reglas sobre una vista) o como parte de un snapshot (el mismo árbol sirve para ambos). No duplica la captura; la comparte.

## Problema

La accesibilidad se prueba tarde o nunca. Apple tiene `performAccessibilityAudit()` (Xcode 15+) pero es solo XCUITest (app corriendo, lento, UI test), y no se integra con los tests unitarios ni con Swift Testing. Faltan aserciones rápidas, a nivel de vista, sobre reglas concretas.

## Objetivos

- **Aserciones de a11y a nivel de vista** (sin XCUITest completo), rápidas y en Swift Testing.
- Reglas concretas y accionables, no un audit opaco.
- Reutilizar el **árbol de a11y** que SpockSnapshot captura (un solo mecanismo).

## No-objetivos

- Reemplazar el audit de Apple en XCUITest para flujos end-to-end.
- Garantizar conformidad legal (WCAG/ADA) completa; cubrimos un subconjunto verificable estáticamente.

## Requisitos funcionales

Aserciones sobre el árbol capturado:

- **Labels y traits:** todo elemento interactivo tiene `accessibilityLabel`; traits correctos (botón es `.button`).
- **Target táctil:** área ≥ 44×44 pt.
- **Contraste WCAG:** ratio texto/fondo ≥ 4.5:1 (AA) / 3:1 (texto grande). Requiere color de texto y fondo del árbol/estilo.
- **Orden de VoiceOver:** orden de lectura razonable (sin saltos), y agrupaciones correctas.
- **Dynamic Type:** el layout no se rompe ni trunca en tamaños accesibles (se apoya en el eje Dynamic Type de Snapshot).
- **Elementos ocultos/decorativos** marcados como tal (`.isAccessibilityElement = false` donde toca).

## Diseño / API (boceto)

```swift
import SpockAccessibility

@Test(.tags(.accessibility))
func homeIsAccessible() {
    let view = HomeView(repository: .stubbed())
    assertAccessible(view, rules: [.labels, .touchTargets(44), .contrast(.AA)])
}
```

Y como parte de un snapshot:

```swift
assertSnapshot(of: view, including: .accessibility(.AA))   // el mismo árbol, dos usos
```

## Dependencias y relación con otras suites

- **SpockSnapshot**: comparte la captura del árbol de a11y. Si Snapshot existe, Accessibility es "solo reglas".
- **SpockMock** para llevar la vista a estados concretos antes de auditar.

## Riesgos y preguntas abiertas

- **Contraste** necesita color efectivo de texto y fondo; extraerlo del árbol de a11y puede ser lossy (gradientes, imágenes de fondo). ¿Hasta dónde llega la verificación estática sin render?
- Solapamiento con `performAccessibilityAudit()`: diferencial = unitario, rápido, Swift Testing, reglas explícitas. ¿Suficiente?
- ¿Módulo separado o un trait de SpockSnapshot? (El usuario pidió PRD propio; la decisión queda documentada aquí.)
