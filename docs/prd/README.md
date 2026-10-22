# PRDs de la suite Spock

Documentos de requisitos de producto por módulo. Borradores para iterar; no son compromisos de implementación.

- [00 — Spock (paraguas)](00-overview.md): visión, la tesis común, mapa de módulos, secuencia.
- [01 — SpockMock](01-spock-mock.md): dobles (stubs, mocks, espías). **Entregado** (2.0.0-beta.1).
- [02 — SpockSnapshot](02-spock-snapshot.md): snapshot semántico de UI en dos capas. El de mayor valor diferencial.
- [03 — SpockRegression](03-spock-regression.md): record/replay de servicios (fixtures HAR versionados) para integración/E2E fiable sin la fragilidad de pegarle al backend real.
- [04 — SpockPerformance](04-spock-performance.md): baselines de rendimiento versionados. Prioridad baja.
- [05 — SpockAccessibility](05-spock-accessibility.md): aserciones de accesibilidad sobre el árbol de a11y.

Tesis común: **artefactos de test versionados, con detección de desfase** (generar → commitear → `check`). Detalle en el [overview](00-overview.md).
