#!/bin/bash
# Genera Resources/AppIcon.icns con el dibujo de BrandMark (Sintecla --make-icon) e iconutil.
# Solo hace falta si cambia el diseño del icono: el .icns va en git.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Sintecla 2>&1 | tail -1
BIN="$(swift build -c release --product Sintecla --show-bin-path)/Sintecla"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
"$BIN" --make-icon "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
echo "✅ Resources/AppIcon.icns"
