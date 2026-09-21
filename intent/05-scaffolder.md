# scaffolder.md — Instructions for Claude Code: Initialize Codebase

## Purpose

This file is an instruction set for **Claude Code** (run locally by the team, in a terminal, on a machine with Flutter/Android tooling installed) to scaffold the initial project structure. It follows the tech stack and architecture decided in `intent.md` and `spec.md`. This is a **scaffolding pass only** — create the folder structure, dependencies, and file stubs with clear TODO comments referencing the relevant spec.md section. Do **not** implement business logic in this pass; that happens afterward, informed by these stubs.

Read `intent.md` and `spec.md` in full before starting, so stub comments accurately reference the right decisions.

## Prerequisites (assumed already installed on the dev machine)

- Flutter SDK (stable channel)
- Android SDK + a connected/emulated Android device (min SDK 24+ recommended for a modern WebView/`webview_flutter` implementation)
- JDK 17
- Git

If any of these are missing, stop and tell the user rather than trying to install system-level tooling silently.

## Step 1 — Create the Flutter project

```bash
flutter create --org com.adchackathon --project-name job_access_assist .
```

(Team: replace `job_access_assist` and the org string with your actual chosen project/team name once decided — see intent.md's "To fill in" checklist.)

Set Android as the only target platform for now (per spec.md — Android-only for the working prototype; iOS is not built):

```bash
flutter config --no-enable-ios
```

## Step 2 — Add dependencies to `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  speech_to_text: ^latest       # STT — wraps Android SpeechRecognizer (spec.md §1)
  flutter_tts: ^latest          # TTS — wraps Android TextToSpeech (spec.md §1)
  http: ^latest                 # OpenAI API calls (spec.md §2)
  shared_preferences: ^latest   # local state only — language pref, applicant profile, last search (spec.md §8)
  permission_handler: ^latest   # runtime mic permission
  provider: ^latest             # lightweight state management — FSM exposed via ChangeNotifier
  webview_flutter: ^latest      # embedded WebView + JS injection/bridge for reading/acting on job portals (spec.md §1, §5)
  syncfusion_flutter_pdf: ^latest  # PDF text/field extraction for application forms (spec.md §1) — TODO: confirm this is still the team's final pick per spec.md §"To fill in", swap for pdf_text if it isn't

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^latest              # for mocking services in FSM unit tests (spec.md §5 architecture note)
```

Run `flutter pub get` after editing.

## Step 3 — Folder structure to create

```
lib/
  main.dart                          # app entrypoint, sets up Provider(s)
  app.dart                           # MaterialApp root widget

  core/
    theme.dart                       # contrast-checked color tokens (spec.md §7, WCAG 1.4.3/1.4.11)
    constants.dart                   # command phrasing templates, confidence thresholds (spec.md §6.1)

  orchestration/
    application_flow_fsm.dart        # the FSM — states + transitions (spec.md §5 architecture note)
    application_flow_state.dart      # sealed class / enum of FSM states
    application_flow_event.dart      # events that trigger transitions

  services/
    speech_service.dart              # wraps speech_to_text; n-best hypotheses + confidence (spec.md §6.1)
    tts_service.dart                 # wraps flutter_tts; narration calls
    openai_service.dart              # intent parsing, DOM/PDF content filtering, image-to-text, form-field matching (spec.md §1, §6)
    webview_controller_service.dart  # Dart side of the WebView + JS-bridge (spec.md §5) — loads target page, runs injected JS, exposes DOM read/fill results
    pdf_reader_service.dart          # wraps the chosen PDF library; extracts text/field structure from an application-form PDF (spec.md §1, §6)
    preferences_service.dart         # SharedPreferences wrapper (spec.md §8)
    fuzzy_match_service.dart         # matches STT text / applicant-profile fields against detected form field labels (spec.md §6.1, §6)

  models/
    job_listing.dart                 # title, company, requirements, how-to-apply — read aloud for user
    application_summary.dart         # filled-in form field values — read aloud before submit confirmation
    voice_command_result.dart        # transcript, confidence, n-best alternatives
    dom_snapshot.dart                 # simplified representation of the WebView page's DOM (images, form fields, text)

  ui/
    screens/
      home_screen.dart               # trigger button + live status/narration readout
      settings_screen.dart           # language toggle (EN/VI)
    widgets/
      voice_trigger_button.dart      # must carry a Semantics label (spec.md §7, WCAG 3.3.2/4.1.2)
      status_narration_view.dart     # visible text mirror of what's being spoken (not audio-only)

  utils/
    logger.dart                      # local debug logging only (spec.md §3)

assets/
  js/
    dom_reader.js                     # injected script — enumerates images (src/alt), form fields (tag/label), page text (spec.md §5, §6, THE core spike target)
    form_filler.js                    # injected script — locates a form field and sets its value, dispatches input/change events (spec.md §5, §6)

android/
  app/src/main/kotlin/com/adchackathon/<app_package>/
    MainActivity.kt                          # standard Flutter entrypoint — no custom platform channel needed for WebView access (webview_flutter handles this)

  app/src/main/AndroidManifest.xml            # RECORD_AUDIO + INTERNET permissions

test/
  orchestration/
    application_flow_fsm_test.dart    # unit tests for state transitions, per spec.md §5 (testable without live device)

docs/
  intent.md                           # copy in, for reference alongside the code
  spec.md
```

## Step 4 — Create file stubs

For every `.dart` and `.kt` file listed above, create it with:
1. A file-level doc comment stating its single responsibility (one sentence)
2. A `// TODO:` comment block referencing the specific spec.md section that defines its behavior
3. Minimal skeleton code so the project **compiles** (empty class/function bodies, correct signatures where the interface is already implied by spec.md — e.g. `SpeechService` should expose a method returning `VoiceCommandResult` with `transcript`, `confidence`, and `alternatives` fields, per spec.md §6.1) — but no actual logic.

Example stub (`lib/services/speech_service.dart`):

```dart
/// Wraps the `speech_to_text` plugin. Owns locale selection (en-US/vi-VN,
/// driven by the user's language preference) and confidence-threshold
/// gating before a transcript is passed downstream.
/// See spec.md §6.1 "Voice Command Intake" for the full mitigation chain
/// this service is responsible for (locale pinning, confidence threshold,
/// n-best hypotheses).
class SpeechService {
  // TODO: initialize speech_to_text, set locale from PreferencesService
  // TODO: listen(), returning VoiceCommandResult with transcript/confidence/alternatives
  // TODO: confidence threshold check — below threshold, caller should re-prompt, not proceed
}
```

Apply the same standard (doc comment + TODOs citing spec.md + compiling skeleton) to every file in the tree above.

## Step 5 — Android manifest permissions

In `AndroidManifest.xml`, add:
- `<uses-permission android:name="android.permission.RECORD_AUDIO" />`
- `<uses-permission android:name="android.permission.INTERNET" />`

No custom `<service>` registration or accessibility-service config is needed — the WebView is hosted directly by the app via `webview_flutter`, so there's no OS-level accessibility permission to request for reading the target page's content (unlike the old `AccessibilityService` approach). `assets/js/dom_reader.js` and `assets/js/form_filler.js` (Step 3) should be registered in `pubspec.yaml`'s `flutter: assets:` list so they can be loaded and injected via `WebViewController.runJavaScript`/`runJavaScriptReturningResult`.

## Step 6 — Secrets handling

- Create a `.env` file (or `android/local.properties` entry) for `OPENAI_API_KEY` — **do not hardcode it in any `.dart` or `.kt` file**
- Add `.env` (or `local.properties`, if not already) to `.gitignore`
- Add a `.env.example` with `OPENAI_API_KEY=` (empty) so teammates know the variable name without the real key ever touching Git
- This is the mitigation for the client-side-key risk flagged in spec.md §3 — it doesn't fix the fundamental issue (key still ships in the built APK) but it does stop it from leaking via the Git repo, which is the more immediate risk for a team pushing to GitHub during a hackathon

## Step 7 — Git

```bash
git init
git add .
git commit -m "Scaffold: initial project structure per spec.md architecture"
```

Confirm `.gitignore` actually excludes `.env`/`local.properties`, build artifacts (`build/`, `.dart_tool/`), and IDE files before this first commit — check `git status` shows nothing sensitive staged.

## Step 8 — Verification checklist

After scaffolding, confirm:
- [ ] `flutter run` builds and launches to a blank/stub home screen with no compile errors
- [ ] `flutter test` runs (even with placeholder/no-op tests) with no errors
- [ ] Android project (`android/`) opens in Android Studio without Gradle sync errors
- [ ] `.env`/`local.properties` confirmed excluded from `git status`
- [ ] Folder structure matches Step 3 exactly, so all three team members can navigate it without guessing

## What NOT to do in this pass

- Do not implement the FSM's actual transition logic
- Do not implement the real WebView/JS-bridge DOM-reading or form-filling logic, or the real PDF-parsing logic — that's the spike (plan.md Workstream A1), done as its own focused session, not folded into scaffolding
- Do not write real OpenAI prompt content yet — stub the method signature only
- Do not add UI polish/styling beyond what's needed to confirm the app compiles and is navigable

This keeps the scaffold fast (should take under an hour) and leaves the team a clean, shared starting point to build the real logic into afterward.
