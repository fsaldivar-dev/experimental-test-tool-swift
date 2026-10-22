# PRD — SpockPerformance

> Estado: diseño · Parte de la suite Spock · Encaje más débil con la tesis; prioridad baja

## Nota de alcance

Es el módulo menos natural del paraguas: medir tiempo/memoria es ortogonal a generar dobles. Entra **solo** si se enmarca en la tesis de Spock: un **baseline de rendimiento es un artefacto versionado con chequeo de regresión**, igual que un snapshot. Si no aporta sobre XCTest, no se construye.

## Problema

`measure {}` de XCTest existe pero: los baselines viven en un plist opaco por device dentro del `.xcodeproj`, no se revisan en el PR, Swift Testing **no tiene** medición de rendimiento, y el ruido de CI hace que los umbrales fijos fallen de forma intermitente.

## Objetivos

- **Baselines versionados** y legibles (archivo commiteado, no plist oculto), revisables en el PR.
- Detección de **regresión** con umbral relativo y tolerancia al ruido (percentiles, no promedio).
- Integración con **Swift Testing** (que hoy no mide rendimiento).
- Métricas: tiempo de pared, y si se puede, asignaciones (`os_signpost`/`mach`), no solo wall-clock.

## No-objetivos

- Microbenchmark con rigor estadístico de laboratorio (eso es package-benchmark de ordo-one; deferir ahí si el usuario quiere rigor).
- Perfilado (Instruments).
- Rendimiento de UI / render (pertenecería a SpockSnapshot si acaso).

## Requisitos funcionales

- `measurePerformance { … }` → corre N iteraciones con warmup, descarta outliers, registra percentiles en `Generated/Performance/<Suite>/<test>.json`.
- Falla si el p50/p90 regresa más de un **umbral relativo** configurable sobre el baseline commiteado.
- `spock-gen perf record` para fijar un baseline nuevo; `check` en CI.
- El baseline guarda **procedencia** (máquina/SO/toolchain); en CI se compara contra el baseline de ese entorno o se marca warning si no coincide.

## Diseño / API (boceto)

```swift
import SpockPerformance

@Test(.tags(.performance))
func parsesLargePayload() {
    measurePerformance(threshold: .relative(0.15)) {
        _ = PayloadParser.parse(bigJSON)
    }
}
```

## Dependencias y relación con otras suites

- Comparte el modelo "artefacto versionado + check" y la CLI `spock-gen`.
- **SpockMock** para construir inputs grandes y deterministas.

## Riesgos y preguntas abiertas

- **El ruido de CI** es el riesgo central: runners compartidos varían ±20-50%. ¿Umbrales relativos y percentiles bastan, o CI de rendimiento necesita hardware dedicado? Si no se resuelve, el módulo da falsos positivos y pierde confianza.
- Solapamiento con **package-benchmark** (ordo-one), que ya hace esto con rigor. Diferencial de Spock: integración con Swift Testing y baselines legibles/versionados. ¿Suficiente?
- Prioridad: **última** de la suite; no construir hasta que Mock y Snapshot estén probados.
