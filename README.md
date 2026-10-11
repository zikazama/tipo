# TIPO — TIten POsko

**Read the signs. Act first.**

TIPO is an AI triage copilot for disaster posko and BPBD operators. It is a prototype for the Google Cloud AI Builder Cup 2026, Sustainability theme. The name expands to **TI**ten **PO**sko: *ilmu titen* is the Javanese practice of reading repeated signs in nature. Here the signs are citizen reports, and the reader is a small team of Gemini agents sitting next to a human operator.

Citizens already have channels. What the posko does not have is a layer that turns a pile of photos, Sundanese and Javanese voice notes, chats, and map reports into one ticket, a credibility explanation, a logistics estimate, and a situation-report draft. TIPO does that. It never broadcasts a public alert by itself.

## Problem

BNPB recorded 1,730 natural disasters across Indonesia in 2026. During a flood the posko receives the same street many times, plus old photos and unstructured voice notes, and still has to write the sitrep by hand. BPBD Bali has already started training staff to use AI agents for that exact job: collect, group, and summarize disaster information from many sources.

## What the prototype does

1. A citizen sends a photo, a voice note, text, and a GPS pin from the Android app (the same screens run on the web as a phone preview).
2. **Intake** extracts hazard, place, severity, people affected, vulnerable groups, needs, language, and an English rendering.
3. **Verification** scores credibility and says why: EXIF time and GPS, visual cues, a BMKG forecast or quake feed, and nearby reports. A missing EXIF timestamp is neutral, not proof of a fake.
4. **Dedup** merges reports of the same incident across app, voice, a simulated WhatsApp channel, and a PetaBencana-style channel. A low-credibility claim stays in its own ticket.
5. **Triage** sets a priority, estimates water, meals, and boats, suggests a seeded team, and drafts a BNPB-style sitrep.
6. An operator approves, edits, or rejects. Only then do reporter updates and nearby alerts go out.

## Design

- **Brand.** Deep navy `#0B1F3A`, orange `#FF7A1A`, and white. Poppins for headings, Inter for body text, both bundled in the app so it works offline. The logo is an orange rounded square with a navy posko tent and a white heartbeat line. It is drawn natively in Flutter and also ships as launcher, adaptive, splash, and web icons.
- **Citizen app.** Light and dark Material 3 themes with Indonesian-first copy. The home screen leads with a large *Lapor sekarang* (Report now) button and a BMKG weather card. The report form is one guided page: hazard, photo, hold-to-record voice note with a live waveform, optional text, GPS with a mini map, and a language hint. After sending, a five-step timeline follows the report (received, verified, merged, triaged, operator decision) and shows the English rendering. The inbox colours each message by severity.
- **Posko console.** Dark navy with orange accents. It has a left nav rail and a top bar with live replay progress. Below that sit a sortable incident queue, a dark OSM map with severity markers and the 2 km alert radius, an agent activity feed, and a tabbed detail drawer: Summary, Evidence, Credibility, Priority, Logistics, Sitrep. Suspected hoaxes get a red warning with reasons. *Approve and send alert* always opens a confirm dialog showing the alert text, the radius, and how many devices it reaches.
- **Accessibility.** Text meets WCAG AA contrast: orange buttons carry navy text, and orange text on white uses a darker ink. Controls have semantic labels and 48 px touch targets.

## Architecture

```text
Flutter (one codebase)
  Android citizen app  +  Flutter web posko console
        │  HTTP
        ▼
FastAPI on Cloud Run
  ADK SequentialAgent: intake → verification → dedup → triage
  tools: BMKG forecast, autogempa, nowcast RSS
        │
        ▼
Firestore (or memory) · Cloud Storage (or local files) · FCM after approval
```

The diagram and the model table are in [docs/architecture.md](docs/architecture.md).

## Repository

| Path | What it is |
| --- | --- |
| `backend/` | Python API, ADK agents, Dockerfile, pytest |
| `app/` | Flutter citizen app and operator console |
| `scenario/` | Dayeuhkolot flood: 25 reports, shelters, BMKG snapshot, simulated media |
| `infra/` | Cloud Run and Firebase scripts, Firestore rules, env example |
| `docs/` | Architecture, 3-minute demo script, judging map |

## Run it locally in mock mode

Mock mode needs no GCP project and no API key. Agent output is deterministic.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8765
```

In another shell:

```bash
cd app
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8091 \
  --dart-define=API_BASE=http://127.0.0.1:8765
```

Open the posko console at `http://127.0.0.1:8091`. Press **Replay scenario**. Twenty-five reports stream in over about 78 seconds: one critical flood at Dayeuhkolot, a high ticket at Baleendah, a medium one at Bojongsoang, a small landslide at Cangkuang Wetan, and a separate low-credibility ticket for two old photos.

The citizen flow is linked from the console (**Citizen app**). On a phone-width window or an Android device it is the home screen. Sample buttons send a Sundanese voice note, a Javanese voice note, a simulated flood photo, or the old-photo case.

```bash
curl -X POST 'http://127.0.0.1:8765/api/replay?wait=true'
curl http://127.0.0.1:8765/api/incidents
```

`wait=true` with `TIPO_REPLAY_SPEED=0` ingests the drill immediately. The default speed is 1.

### Android

```bash
cd app
flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8765
```

Use your machine's LAN IP instead of `10.0.2.2` on a physical device. Camera, microphone, and location permissions are declared. The in-app inbox is the mock stand-in for FCM.

### Tests

```bash
cd backend && pytest
cd app && flutter analyze && flutter test
```

## Live Gemini

```bash
export TIPO_MODE=live
export GOOGLE_API_KEY=your-key
# or: GOOGLE_GENAI_USE_VERTEXAI=true, GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_LOCATION
```

Restart the API. A submitted report is reviewed by the ADK pipeline (`gemini-3.8-flash` for intake, verification, and triage; `gemini-3.5-flash-lite` for dedup). The trace on the ticket says `live` or `live_fallback`. Replay stays on the deterministic path so the drill does not spend a quota or change shape between takes.

Model names default to the ids published on [ai.google.dev/gemini-api/docs/models](https://ai.google.dev/gemini-api/docs/models) as of 10 Oct 2026. Override them with `TIPO_MODEL_MAIN`, `TIPO_MODEL_LITE`, `TIPO_MODEL_TRANSCRIBE`, and `TIPO_MODEL_EMBED`. See [infra/env.example](infra/env.example). Do not commit keys.

## Deploy

Cloud Run, from the repo root, after `gcloud auth login` and a project with billing:

```bash
PROJECT=your-project REGION=asia-southeast2 ./infra/deploy-cloud-run.sh
```

The container starts in mock mode. Set `TIPO_MODE=live` and `GOOGLE_API_KEY` (or Vertex) on the service when you want Gemini. Optional: `TIPO_STORE=firestore`, `TIPO_GCS_BUCKET`, `TIPO_FCM=true`, and `FIREBASE_SERVICE_ACCOUNT_JSON`.

Flutter web on Firebase Hosting:

```bash
API_BASE=https://your-cloud-run-url FIREBASE_PROJECT=your-project ./infra/deploy-hosting.sh
```

`firebase.json` serves `app/build/web` and the rules in `infra/firestore.rules`. Those rules deny all client access; the API uses the Admin SDK.

Firebase in the app is optional. `app/lib/firebase_options.dart` is a placeholder. The project builds with no `google-services.json`. After `flutterfire configure`, pass `--dart-define=USE_FIREBASE=true` and add `firebase_core` / `firebase_messaging`. Until then the three push types (reporter status, nearby alert, operator ticket) are delivered to the in-app inbox, which is what FCM would carry.

## Gemini and ADK, in short

- The graph is built in `backend/app/agents/adk_pipeline.py` with `google-adk` 2.11.
- Verification tools are real Python functions the agent can call: `bmkg_forecast`, `bmkg_earthquakes`, `bmkg_nowcast`.
- Live execution is `InMemoryRunner` in `backend/app/agents/live.py`.
- Dedup embeddings target `gemini-embedding-2-preview`. Mock mode uses a deterministic token embedding and says so in the trace.
- ADK 2.11 deprecates `SequentialAgent` in favor of `Workflow`. This code keeps `SequentialAgent` because that is the sequential multi-agent the product is, and it runs. Workflow cannot yet be nested as an `LlmAgent` sub-agent.

## Scenario

`scenario/dayeuhkolot_flood.json` is a flood drill for Desa Dayeuhkolot, Kabupaten Bandung, plus Baleendah, Bojongsoang, and a small landslide at Cangkuang Wetan. It includes duplicate reports, one pair of old-photo claims, and Sundanese and Javanese transcripts. Photos are drawn placeholders. Audio files are short tones; the words are in the matching `.txt` files. Regenerate with `python scenario/generate_scenario.py`.

BMKG adm4 codes confirmed during the build:

| Place | adm4 |
| --- | --- |
| Desa Dayeuhkolot | `32.04.12.2002` |
| Desa Cangkuang Wetan | `32.04.12.2003` |
| Desa Bojongsoang | `32.04.08.2002` |

Baleendah's kelurahan code was not confirmed before the forecast API rate-limited. Its weather figures are part of the recorded snapshot and are labeled that way.

## Limitations

- Mock agents are rules with the same output contract as the model, not a hidden Gemini call.
- Live mode rewrites narrative fields. Geo clustering stays deterministic on purpose.
- FCM, Firestore, and Cloud Storage are implemented behind env flags and are not exercised without your project.
- There is no WhatsApp Business API, no iOS build, and no forensic deepfake detector.
- Seed media is simulated. Do not treat the drill as a live disaster feed.
- The product name collides mildly with the Indonesian slang *tipo* (typo) and with unrelated apps. The expansion TIten POsko is on the wordmark for that reason.

## Credits and sources

Team named in the concept: Zikazama Builders (Fauzi and Taufik).

- BNPB disaster count, 2026, via Antara: https://en.antaranews.com/news/430332/bnpb-reports-1730-natural-disasters-across-indonesia-in-2026
- BPBD Bali exploring AI for situation reports: https://bali.antaranews.com/berita/414613/bpbd-bali-eksplorasi-ai-perkuat-informasi-penanggulangan-bencana
- Ilmu titen on the Merapi slopes: https://regional.espos.id/ilmu-titen-kearifan-lokal-warga-lereng-merapi-hadapi-erupsi-1334638
- BMKG on ilmu titen and mitigation: https://www.kompas.com/jawa-tengah/read/2025/02/06/190030588/kepala-bmkg-sebut-ilmu-titen-jawa-bisa-digunakan-untuk-mitigasi
- Simeulue and smong, as pitch context only: https://reliefweb.int/report/indonesia/story-saved-lives-people-simeulue-indonesia
- BMKG open data: forecast API, autogempa, gempaterkini, nowcast RSS
- Map tiles: OpenStreetMap contributors, via flutter_map. Review the [tile usage policy](https://operations.osmfoundation.org/policies/tiles) before a production deployment.
- Gemini and ADK: https://ai.google.dev/gemini-api/docs/models and https://google.github.io/adk-docs/
- Fonts: Poppins and Inter, SIL Open Font License 1.1. License texts are in `app/assets/fonts/`.

## Demo and judging notes

- [Three-minute demo script](docs/demo-script.md)
- [How this maps to the judging weights](docs/judging-criteria.md)
