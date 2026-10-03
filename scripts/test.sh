#!/bin/bash
# Los tests (Swift Testing), con el SDK que compila con estas Command Line Tools (ver sdk-env.sh).
#   scripts/test.sh                  → todos
#   scripts/test.sh --filter Nombre  → solo los que coinciden
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sdk-env.sh
swift run sintecla-tests "$@"
