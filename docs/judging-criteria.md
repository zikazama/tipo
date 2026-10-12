# Judging criteria

Google Cloud AI Builder Cup 2026, Sustainability theme. Weights below are the ones in the brief we built against.

## Technical and GenAI — 40%

- Four-agent ADK `SequentialAgent` in Python, exposed by FastAPI, with a Cloud Run Dockerfile.
- Models are the current Gemini ids (`gemini-3.8-flash`, `gemini-3.5-flash-lite`, `gemini-3.5-transcribe`, `gemini-embedding-2-preview`) and are env-configurable.
- Tools call real BMKG forecast, earthquake, and nowcast endpoints. The drill uses a recorded snapshot so judges are not blocked by a dry forecast or a rate limit.
- Mock mode runs with no keys. Live mode calls Gemini and falls back without taking the demo down.
- Pytest covers each agent plus the API, including the rule that no nearby alert exists before approval.
- Flutter analyze is clean. Widget tests cover the citizen home, the empty report, the operator queue, and the sitrep.

## Problem and impact — 25%

- The user is the posko operator, not another public map. BNPB's 1,730 disasters in 2026 and BPBD Bali's own AI training for situation reports are the need.
- Impact shown in the product: duplicate reports become one ticket, an old photo is held aside with reasons, logistics and a team are suggested, and a sitrep is one click instead of an hour of copy-paste.
- The Dayeuhkolot scenario is a real flood-prone kelurahan on the Citarum, with adm4 codes checked against BMKG. A second Pelalawan karhutla drill shows the same operator loop on peatland fire.

## Innovation — 25%

- Operator-side triage, not another citizen pin.
- Official BMKG cross-check plus EXIF and visual cues, explained, not a fake/real verdict.
- Sundanese and Javanese voice notes become the same English ticket as app text, WhatsApp-sim messages, and PetaBencana-channel reports.
- Low-credibility claims cannot contaminate a confirmed cluster.
- The loop returns to residents only after a human approves.

## UX — 10%

- One Flutter codebase: Android citizen app and a web posko console.
- The console is a night desk: map, priority queue, credibility reasons, and an explicit approve button.
- The citizen app is a daylight field tool with sample voice notes so a judge can try Sundanese and Javanese without a microphone.
- Empty, loading, and API-down states are written in plain language.
- Replay is one button and finishes in about 78 seconds.

## What we are not claiming

- This is not an official BNPB or BMKG system.
- Credibility is a signal. The operator decides.
- Seed photos are drawings labeled SIMULATED. Voice files are tones plus transcripts, not field recordings.
- WhatsApp Business API, deepfake forensics, and a live BPBD integration are out of scope.
