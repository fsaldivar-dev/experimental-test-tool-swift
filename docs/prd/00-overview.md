# PRD — Spock (paraguas)

> Estado: visión · Documento sombrilla de la suite

## Qué es Spock

Un **conjunto de librerías de testing para Swift** bajo una sola marca y un solo paquete SPM, cada una enfocada en un problema, todas unidas por la misma tesis de diseño. No es un framework monolítico: importas solo el módulo que necesitas.

```swift
// Package.swift del consumidor
dependencies: [.package(url: "…/experimental-test-tool-swift", from: "2.0.0")]

import SpockMock         // dobles: stubs, mocks, espías
import SpockSnapshot     // snapshots semánticos de UI
import SpockRegression   // golden master de valores y lógica
import SpockPerformance  // baselines de rendimiento
import SpockAccessibility// aserciones de accesibilidad
```

## La tesis que une a todas

**Artefactos de test versionados, con detección de desfase.** Cada módulo:

1. **Genera** un artefacto (stub, snapshot, golden value, baseline) a partir de la estructura real (dominio, vista, función).
2. **Lo commitea** junto a los tests, como fuente de verdad revisable en el PR.
3. **Chequea desfase** (`spock-gen check` o su equivalente): si lo que se generaría ya no coincide con lo commiteado, falla con un diff legible.

Es el mismo modelo que hizo exitoso a swift-snapshot-testing, aplicado de forma uniforme a dobles, snapshots, regresión y rendimiento. La diferencia de Spock: **sin build-tool plugins** (el artefacto ya está en git), **DX unificado** (misma CLI, mismo layout `Generated/`, mismo estilo Given/When/Then) e **integración nativa con Swift Testing**.

## Mapa de módulos

| Módulo | Qué genera y chequea | Estado |
| --- | --- | --- |
| **SpockMock** | Dobles: `Tipo.stub(...)`, `ProtocoloMock`, `TipoSpy` | Entregado (2.0.0-beta.1) |
| **SpockSnapshot** | Snapshot de UI en dos capas: árbol semántico (FAIL) + píxeles (WARNING) | PRD / diseño |
| **SpockRegression** | Record/replay de servicios: fixtures HAR versionados, re-grabado contra vivo como señal de contrato | PRD / diseño |
| **SpockPerformance** | Baselines de tiempo/asignaciones versionados | PRD / diseño |
| **SpockAccessibility** | Aserciones sobre el árbol de accesibilidad (WCAG, target 44pt, labels) | PRD / diseño |

Regresión y accesibilidad comparten la tesis con Snapshot (ver sus PRDs): Regression es record/replay de servicios (HAR versionado + re-grabado como señal de contrato), misma idea de artefacto versionado con detección de desfase; Accessibility son aserciones sobre el mismo árbol de a11y que Snapshot captura.

## Infraestructura compartida

- **`spock-gen`**: la CLI (`generate | check | clean`), reutilizada por los módulos que generan archivos.
- **Layout `Generated/`**: un archivo por artefacto, reflejando la estructura de origen, commiteado.
- **Integración con Swift Testing**: traits (`.record`, `.tags`), `#expect`, suites `struct`; XCTest también.
- **Determinismo**: los dobles de SpockMock alimentan datos estables a SpockSnapshot/Regression.

## Secuencia (no todo a la vez)

1. **SpockMock** — entregado; falta validación en un proyecto real para dejar el beta.
2. **Reestructurar el paquete en módulos** bajo el paraguas (hoy es un solo producto `SpockSwift`).
3. **SpockSnapshot** — el de mayor valor diferencial; se diseña a fondo.
4. **SpockRegression / SpockAccessibility** — se apoyan en 3.
5. **SpockPerformance** — último, el de encaje más débil con la tesis.

## Principio de alcance

API pequeña por módulo. Donde una herramienta madura ya resuelve bien un caso (XCTest para baselines, swift-snapshot-testing para píxel exacto), Spock **defiere** y lo dice, en vez de competir por competir. Cada PRD tiene una sección de **No-objetivos** explícita.

## Preguntas abiertas

- Nombre: ¿`Spock` como marca y `SpockMock`/`SpockSnapshot`/… como productos? ¿Se conserva `SpockSwift` como re-export sombrilla?
- ¿La reestructuración en módulos entra antes del 2.0.0 final (ventana de beta) o después?
- ¿Linux aplica a todos los módulos, o Snapshot/Accessibility quedan Apple-only por depender de UIKit/a11y?
