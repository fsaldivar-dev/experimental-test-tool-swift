# 🧩 Spock Xcode Source Editor Extension

Esta extensión integra **SpockSwift 2** de forma nativa directamente en la barra de menú de **Xcode**.

---

## 🎯 Comandos Disponibles en Xcode (`Editor > Spock`)

Una vez activada, encontrarás las siguientes acciones en el menú **Editor > Spock** (o mediante atajos de teclado configurables):

1. **`Spock: Generate Stubs`**:
   - Escanea el proyecto o el archivo activo y regenera de inmediato `Stubs.generated.swift`.
   - Si tienes abierto `Stubs.generated.swift` en el editor, el buffer se actualiza instantáneamente en pantalla sin necesidad de recargar.

2. **`Spock: Add @Stubbed to Selection`**:
   - Agrega automáticamente `@Stubbed extension <Modelo> {}` o la anotación `@Stubbed` sobre el modelo o texto seleccionado en el editor de Xcode.
   - Dispara la generación automática tras insertar el código.

3. **`Spock: Clean Stubs`**:
   - Purga el archivo de caché incremental y resetea los stubs a un estado limpio.

4. **`Spock: Toggle Watch Daemon`**:
   - Inicia o detiene el demonio en segundo plano (`spock-gen daemon start/stop`) con un solo clic desde Xcode.

---

## 🚀 Cómo Habilitar la Extensión en macOS y Xcode

1. **Compilar la Extensión:**
   - Abre `Example/Example.xcworkspace` o `EditorExtension/SpockExtension.xcodeproj` en Xcode.
   - Selecciona el esquema **SpockXcodeExtension** con destino **My Mac** y presiona **Build** (`⌘B`) o **Run** (`⌘R`).

2. **Habilitar la Extensión en macOS:**
   - Abre **Ajustes del Sistema (System Settings)** en macOS.
   - Navega a **Privacidad y Seguridad** > **Extensiones** (o busca *"Extensiones"*).
   - Haz clic en **Xcode Source Editor** y activa la casilla para **SpockXcodeExtension**.

3. **Asignar Atajos de Teclado en Xcode:**
   - Abre **Xcode** > **Settings...** (`⌘,`) > pestaña **Key Bindings**.
   - En el buscador escribe `Spock`.
   - Asigna tus atajos preferidos (por ejemplo: `⌃⌥⌘G` para *Generate Stubs*, `⌃⌥⌘A` para *Add @Stubbed to Selection*).
