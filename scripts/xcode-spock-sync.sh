#!/bin/bash
#
# xcode-spock-sync.sh
# SpockSwift 2 - Atajo de sincronización para Xcode
#
# Puede configurarse en Xcode > Settings > Behaviors con un atajo (ej. ⌃⌥⌘S)
# o ejecutarse desde la terminal.
#

set -e

# Detectar directorio raíz del repositorio
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "⚡ SpockGen: Sincronizando stubs para Xcode..."

# Ejecutar spock-gen con auto-detección
swift run spock-gen --verbose

echo "✅ SpockGen: Sincronización completada con éxito."
