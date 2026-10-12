#!/usr/bin/env bash
# Build Flutter web and deploy it to Firebase Hosting.
# Usage: ./infra/deploy-hosting.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${API_BASE:-https://tipo-api-REPLACE.asia-southeast2.run.app}"

cd "$ROOT/app"
# --wasm: skwasm + dart2wasm on Chromium (mobile LCP/TBT win); CanvasKit fallback elsewhere.
# --tree-shake-icons: MaterialIcons drops from ~1.6MB to a small subset (critical on Slow 4G).
# Default CDN CanvasKit (do NOT pass --no-web-resources-cdn): parallel download vs main.dart.js.
flutter build web --release --wasm --tree-shake-icons \
  --enable-wasm-deferred-loading \
  --dart-define="API_BASE=${API_BASE}" ||
flutter build web --release --wasm --tree-shake-icons \
  --dart-define="API_BASE=${API_BASE}"

# Symbol maps are for local debugging; do not ship them to judges.
find build/web -name '*.symbols' -delete
find build/web -name '*.js.map' -delete
find build/web -name '*.wasm.map' -delete

cd "$ROOT"
firebase deploy --only hosting,firestore:rules --config firebase.json --project "${FIREBASE_PROJECT:?Set FIREBASE_PROJECT}"
