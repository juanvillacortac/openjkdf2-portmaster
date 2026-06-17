#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/OpenJKDF2/build_linux64_gles_kms.sh" "$@"
