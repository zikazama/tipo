#!/usr/bin/env bash
# Build Flutter web and deploy it to Firebase Hosting.
# Usage: ./infra/deploy-hosting.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${API_BASE:-https://tipo-api-REPLACE.asia-southeast2.run.app}"

cd "$ROOT/app"
flutter build web --release --dart-define="API_BASE=${API_BASE}"
cd "$ROOT"
firebase deploy --only hosting,firestore:rules --config firebase.json --project "${FIREBASE_PROJECT:?Set FIREBASE_PROJECT}"
