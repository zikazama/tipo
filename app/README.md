# TIPO Flutter app

One Flutter codebase for the Android citizen app and the Flutter web posko console. Setup, mock mode, live Gemini, and deploy steps are in the repository [README](../README.md).

```bash
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8091 \
  --dart-define=API_BASE=http://127.0.0.1:8765
```

The web build opens the posko console. The citizen flow is at `/`. Android uses the same routes and does not need a Firebase project while `USE_FIREBASE` is false.

## Layout

| Path | What it is |
| --- | --- |
| `lib/core/theme.dart` | Brand colours, spacing, radii, motion, and the light, dark, and ops themes |
| `lib/presentation/widgets/` | Logo mark and wordmark, badges, meters, empty/error/loading states, waveform |
| `lib/presentation/citizen/` | Home, report form, status timeline, my reports, inbox |
| `lib/presentation/ops/` | Console shell, queue, map, detail drawer, activity feed, sitrep |
| `lib/domain/insights.dart` | Client mirrors of API rules: alert preview, nearby recipients, evidence flags, priority factors |

## Brand assets

Fonts live in `assets/fonts/` with their OFL licenses. Launcher, adaptive, and web icons come from the TIPO logo pack. To regenerate them after changing `assets/icon/`:

```bash
dart run flutter_launcher_icons
```

The Android 12 splash and the web loading screen use the same navy and orange, so there is no white flash on start.
