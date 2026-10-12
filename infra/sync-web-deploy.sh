#!/usr/bin/env bash
# Copy a release web build into the Vercel deploy folder (tipo-web-deploy).
# Run from the monorepo after: cd app && flutter build web --release --wasm --tree-shake-icons ...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/app/build/web}"
DEST="${2:-$ROOT/../../tipo-web-deploy}"

if [[ ! -f "$SRC/main.dart.js" && ! -f "$SRC/main.dart.wasm" ]]; then
  echo "No web build at $SRC. Build first." >&2
  exit 1
fi

rsync -a --delete \
  --exclude '.vercel' \
  --exclude '.git' \
  --exclude 'vercel.json' \
  --exclude '.gitignore' \
  "$SRC/" "$DEST/"

find "$DEST" -name '*.symbols' -delete
find "$DEST" -name '*.js.map' -delete
find "$DEST" -name '*.wasm.map' -delete

echo "Synced $SRC -> $DEST (symbols stripped; vercel.json kept)."
