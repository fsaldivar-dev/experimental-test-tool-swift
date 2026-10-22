# PRD — SpockSnapshot

> Estado: diseño · Parte de la suite Spock · El módulo de mayor valor diferencial

## Problema

El snapshot testing dominante (swift-snapshot-testing) compara **píxeles de una imagen renderizada**, y el render depende del entorno: escala, antialiasing de fuentes, sombras/blur, versión de iOS, SF Symbols. Consecuencias que todo equipo sufre:

- Los tests **fallan en CI al cambiar de simulador o versión de iOS**, aunque la UI sea correcta.
- Un **PDF o vector** rasterizado reintroduce dependencia de resolución.
- Las **animaciones** no caben en una imagen.
- El **diff es una imagen ilegible** en el PR.
- Re-grabar tras un cambio grande (subir el iOS mínimo) es tosco y global.

La raíz común: comparar píxeles es intrínsecamente dependiente del renderer. Ese es el techo del paradigma.

## Objetivos

- Snapshot de UI **independiente del dispositivo** comparando **estructura semántica**, no píxeles.
- Modelo de **dos capas** por snapshot con **severidad por capa**.
- **Re-grabado granular** por alcance y **por capa**.
- Integración nativa con **Swift Testing** (traits, tags).
- Cubrir la **matriz real**: tamaños, apariencia, versión de SO, estados, Dynamic Type.
- Fundir **accesibilidad** (ver [PRD Accessibility](05-spock-accessibility.md)) en el mismo artefacto.

## No-objetivos

- **Reemplazar el snapshot de píxel exacto.** Una regresión de "3px" o "un tono más oscuro" solo se ve en píxeles, y ahí la dependencia del aparato es física. Spock **posee el eje semántico** y lo dice; el píxel es respaldo informativo.
- **Gestos / interacción** antes del snapshot (territorio XCUITest).
- **DUO / foldables / multi-ventana** en el MVP (fase 2).
- Movimiento de animaciones frame a frame (se prueba el spec y la posición de reposo).

## Modelo central: artefacto de dos capas

```
Generated/Snapshots/HomeScreen/
  tree.txt            ← semántico: árbol/posición en reposo. Es la verdad. Diff de texto.
  pixels@3x.png       ← referencia de render. Solo informa.
  meta.json           ← procedencia: SO, toolchain, tema, escala
```

**Severidad por capa:**

| Qué difiere | Significa | Resultado |
| --- | --- | --- |
| El árbol | regresión real (estructura o posición) | **FAIL** |
| Solo píxeles (árbol igual) | escala, antialiasing, versión de SO | **WARNING** |
| Ambos | el árbol manda | FAIL |

Dial configurable: una pantalla donde el color importa usa `pixelPolicy: .strict` para escalar el warning a fail.

## Requisitos funcionales

1. **Captura del árbol semántico.** Anclado en la **jerarquía de accesibilidad** del `UIHostingController`/vista (API pública estable), no en reflexión privada de SwiftUI. Serialización **canónica**: frames en **puntos** (no píxeles), redondeados, orden estable, sin ids generados ni direcciones de memoria. UIKit directo; SwiftUI vía hosting.
2. **Captura de píxeles** por escala, con **umbral perceptual** para el warning.
3. **Congelar animaciones** a su estado de reposo antes de capturar. Animaciones infinitas (spinner, shimmer) → **solo árbol**, sin aserción de píxel.
4. **Ejes de matriz** (config por test o global): `sizes: [.iPhoneSE, .iPhone15ProMax, .iPadPro11]`, `appearance: [.light, .dark, custom]`, `dynamicType: [.large, .accessibilityXXL]`, `locale/RTL`.
5. **Render por SO, no por dispositivo:** la referencia de píxeles se indexa por **versión de SO** (y tema/escala), no por modelo. El árbol es resolución-independiente.
6. **Recursos visuales** (SVG, PNG, PDF): dos capas también — estructura (paths, texto, páginas) como FAIL, ráster como WARNING.
7. **Máscaras** de regiones volátiles (mapa vivo, video, timestamp) y snapshot de subvista.
8. **Determinismo del entorno:** reloj/fecha fijos, semilla para aleatorios, estados inyectados con los dobles de **SpockMock**.
9. **Matriz de estados:** mismo screen en loading / cargado / vacío / error, cada estado un snapshot.
10. **Diff legible:** árbol → diff de texto con el nodo cambiado; píxeles → imagen de diferencias + lado a lado.

## Diseño / API (boceto)

```swift
import Testing
import SpockSnapshot

@Suite("HomeScreen", .tags(.snapshot))
struct HomeScreenSnapshots {
    @Test(.sizes(.iPhoneSE, .iPadPro11), .appearance(.light, .dark))
    func loaded() {
        let repo = UserRepositoryMock()               // SpockMock: datos deterministas
        repo.whenCall(\.fetchUser).returns(.stub(name: "Ana"))
        let view = HomeView(repository: repo)

        assertSnapshot(of: view)                       // dos capas, matriz, reposo
    }
}
```

Re-grabado granular por alcance y capa:

```bash
spock-gen snapshot record --scope test HomeScreen
spock-gen snapshot record --scope suite
spock-gen snapshot record --layer pixels --scope all   # subes el iOS mínimo: solo png, árboles intactos
```

Tags para CI: `tree` barato en cada PR, matriz de `pixels` nightly.

## Dependencias y relación con otras suites

- **SpockMock** para datos deterministas (requisito 8/9).
- **SpockAccessibility**: comparte la captura del árbol de a11y; Accessibility añade aserciones (contraste, 44pt) sobre ese mismo árbol.
- **SpockRegression**: mismo motor de dos fases (generar/commitear/check) aplicado a UI.
- Infra `spock-gen` (record/check) y Swift Testing traits.

## Riesgos y preguntas abiertas

- **Capturar el árbol de SwiftUI** es el riesgo principal. La vía de a11y es estable pero **lossy** (no todo lo visual está en el árbol de a11y). ¿Suficiente para las regresiones que importan? Validar con pantalla real.
- La **serialización canónica** es donde se gana o pierde el determinismo; definir el formato exacto de `tree.txt`.
- La **matriz explota** (tamaño × apariencia × SO × estado × Dynamic Type); paralelismo de Swift Testing y modo `tree-only` para PRs.
- ¿Apple-only? Depende de UIKit/UIHostingController; Linux probablemente fuera para este módulo.
- Banco de pruebas: ¿pantalla de Livery o de Sajaru Corner?
