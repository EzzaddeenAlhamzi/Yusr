# Yusr Track B — Arabic voice feasibility (NON-PRODUCTION)

Isolated Flutter **prototype** under `prototypes/arabic_voice_feasibility/`.

- **Not** the production Yusr app (`lib/main.dart`, root `pubspec.yaml`, production `AndroidManifest`).
- **Do not merge** into production without A8/A9 + PO.
- **Do not** start full P4 from this package.

## What it demos

1. Explicit mic tap  
2. Runtime `RECORD_AUDIO` permission prompt  
3. Short Arabic phrase → on-screen transcript (`speech_to_text`)  
4. Labeled **synthetic** Arabic reply (no PHI / no backend)  
5. On-device Arabic TTS via `flutter_tts` / Android `TextToSpeech`

## Hard exclusions

- No always-on / background mic  
- No silent uploads, no audio file storage  
- No real medication reminders, alerts, emergency escalation, or external actions  

## Run on an Android device

From a machine with Flutter + Android SDK (lab device recommended):

```bash
cd prototypes/arabic_voice_feasibility
flutter pub get
flutter devices
flutter run -d <device_id>
```

Optional release-style debug APK:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Device prerequisites

- Arabic language available to the OS speech recognizer (Settings → Language / Google app offline speech packs help).  
- Arabic voice data installed for Google TTS (or OEM TTS that exposes `ar-*`).  
- Grant microphone when prompted.

### Suggested spoken phrases

`مرحبا` · `كيف حالك` · `ما اسمك` · `شكرا` · `اختبار`

Emergency / medicine words intentionally return a **blocked synthetic** notice (no side effects).

## Analyze / unit tests (no device)

```bash
cd prototypes/arabic_voice_feasibility
flutter analyze
flutter test
```

## Isolation note

Application id: `com.yusr.feasibility.arabic_voice_feasibility`  
Production app remains `com.example.yusr1` and is untouched by this package’s dependencies and permissions.
