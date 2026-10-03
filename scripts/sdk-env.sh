# Se carga con `source scripts/sdk-env.sh` (lo hace build-app.sh) antes de compilar la app.
#
# Las Command Line Tools 27 traen el SDK de macOS 27, donde `@State` de SwiftUI es una macro cuyo plugin solo viene
# con Xcode. Mientras sea así, la app se compila con el SDK de macOS 26, que esas mismas Command Line Tools también
# instalan. Con unas Command Line Tools anteriores no hace falta y no se toca nada.
SDK_26="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [ -z "${SDKROOT:-}" ] && [ -d "$SDK_26" ] && [ ! -e /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib ]; then
  export SDKROOT="$SDK_26"
fi
