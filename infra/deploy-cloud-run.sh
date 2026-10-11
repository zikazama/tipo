#!/usr/bin/env bash
# Build the API image from the repo root and deploy it to Cloud Run.
# Usage: PROJECT=my-project REGION=asia-southeast2 ./infra/deploy-cloud-run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${PROJECT:-$(gcloud config get-value project)}"
REGION="${REGION:-asia-southeast2}"
SERVICE="${SERVICE:-tipo-api}"
IMAGE="${IMAGE:-${REGION}-docker.pkg.dev/${PROJECT}/tipo/tipo-api}"

cd "$ROOT"
gcloud artifacts repositories describe tipo --location="$REGION" >/dev/null 2>&1 || \
  gcloud artifacts repositories create tipo --repository-format=docker --location="$REGION"
gcloud builds submit --tag "$IMAGE" --file backend/Dockerfile .
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "TIPO_MODE=mock,TIPO_MODEL_MAIN=gemini-3.8-flash,TIPO_MODEL_LITE=gemini-3.5-flash-lite,TIPO_MODEL_TRANSCRIBE=gemini-3.5-transcribe,TIPO_MODEL_EMBED=gemini-embedding-2-preview" \
  --memory 1Gi
echo "Set GOOGLE_API_KEY (or Vertex env) and TIPO_MODE=live on the service when you want Gemini."
