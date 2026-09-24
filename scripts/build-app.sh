#!/bin/bash
# Compila Sintecla, la empaqueta como .app, la firma y la instala.
#   scripts/build-app.sh                         → /Applications, y la abre
#   DEST=~/Applications scripts/build-app.sh     → otra carpeta
#   NO_OPEN=1 scripts/build-app.sh               → no la abre al terminar
#   SIGN_ID="Mi certificado" scripts/build-app.sh → firma con un certificado del Llavero
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Sintecla"
BUNDLE_ID="local.sintecla.app"
DEST="${DEST:-/Applications}"
SIGN_ID="${SIGN_ID:--}"

swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --product "$APP_NAME" --show-bin-path)"

APP=".build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ "$SIGN_ID" = "-" ]; then
  # Ad-hoc con requisito fijo: macOS identifica la app por su bundle id,
  # así los permisos sobreviven a cada recompilación.
  codesign --force --sign - --identifier "$BUNDLE_ID" \
    -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
else
  codesign --force --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP"
fi
codesign --verify --strict "$APP"

pkill -x "$APP_NAME" 2>/dev/null || true
# Espera a que la instancia anterior termine y a que LaunchServices la dé por
# cerrada (unas décimas después): si no, `open` intenta reactivarla y falla con -600.
for _ in $(seq 1 50); do
  if ! pgrep -x "$APP_NAME" >/dev/null && [ -z "$(lsappinfo find bundleid="$BUNDLE_ID")" ]; then break; fi
  sleep 0.1
done
mkdir -p "$DEST"
rm -rf "$DEST/$APP_NAME.app"
cp -R "$APP" "$DEST/"
# Finder y el Dock guardan el icono en caché: con la fecha cambiada vuelven a leerlo.
touch "$DEST/$APP_NAME.app"
echo "✅ Instalada en $DEST/$APP_NAME.app"
if [ -z "${NO_OPEN:-}" ]; then open "$DEST/$APP_NAME.app"; fi
