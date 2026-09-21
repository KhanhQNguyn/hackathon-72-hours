# Claude Code audit brief

Audit this Flutter repository for the issues below. Do not modify source files
unless explicitly asked in a later instruction. Treat this as a verification
and review task: inspect the current working tree, run only safe read-only
checks where useful, and distinguish confirmed defects from assumptions that
need an Android device, emulator, live target site, or OpenAI credentials.

The app is a voice-driven Android job-application assistant. Its intended real
flow is: open a selected job listing, read it accessibly, reach the correct
application form, collect and confirm values, then submit only after the user
confirms.

## Audit targets

### 1. OpenAI credential exposure

Verify whether the application packages an OpenAI API key into the Android
artifact. Inspect `pubspec.yaml`, `.env` handling, `main.dart`, and the OpenAI
service. `.gitignore` protection is not sufficient if the key is bundled as a
Flutter asset. Report:

- whether a release APK/AAB can contain the key;
- where the key is loaded and transmitted;
- the severity and practical impact;
- a production-safe remediation, such as a server-side proxy or scoped,
  short-lived credentials.

Do not print any actual secret values.

### 2. Real application-page and form binding

Trace the non-mock path from `AppConfig.targetUrl` through
`ApplicationFlowController`, `WebViewControllerService`, the PDF picker, and
the DOM field selection logic. Verify whether the app actually:

1. identifies a particular listing;
2. navigates to that listing's application page; and
3. obtains fields from that same application form.

Pay close attention to whether a user-selected PDF is only read aloud while
the fields that get filled still originate from the previously loaded page.
If the target defaults to a homepage, determine whether search/login/newsletter
inputs could be mistaken for application fields. Recommend a concrete design
for associating a selected listing, application URL, and expected form.

### 3. Submission outcome verification

Trace `SubmitConfirmed`, the submit hook, JavaScript click code, and the FSM
transition to `DoneState`. Verify whether the implementation merely confirms
that JavaScript invoked `.click()` or whether it proves that the portal
accepted the application. Check for handling of client validation errors,
server errors, redirects, and post-submit confirmation content.

Recommend a post-submit contract that prevents announcing success until the
page provides an independently verifiable success condition.

### 4. Sensitive-field handling

Review DOM field discovery, form filtering, voice collection, stored values,
final-review narration, logs, and AI request payloads. Confirm whether any of
the following can be requested, retained, sent externally, or read aloud:

- passwords;
- one-time passcodes;
- security answers;
- payment details;
- government identifiers.

Specify which input types, autocomplete values, labels, and names should be
blocked or require an alternative, private interaction. The final review must
redact sensitive values even if a field reaches the flow accidentally.

### 5. Image-fetch resource and privacy controls

Review the image-to-text path, especially `defaultImageFetcher`. Check whether
all URL schemes—including `data:` URIs—are subject to a decoded-byte limit,
MIME validation, timeout, and URL/origin policy before image bytes are sent to
the AI provider. Explain any memory-exhaustion, unexpected-network-request, or
data-sharing risks. Recommend bounded decoding and a consent-aware policy for
external image processing.

### 6. Mock-mode release safety

Inspect `AppConfig.useMockServices`, app composition, README/build commands,
and any CI or release configuration. Confirm the behavior of a normal
`flutter run` and production build without `--dart-define`. Decide whether the
current default could ship fake WebView/PDF behavior. Recommend a safe
development-versus-release configuration and a test that prevents regression.

## Required report format

Write findings in priority order using this structure:

```text
## [Severity] Short title

Status: Confirmed / Partially confirmed / Needs device or live-service test

Evidence:
- path:line — concise description of the relevant behavior

Impact:
- concrete user, privacy, security, or product consequence

Recommendation:
- smallest credible remediation

Validation:
- test or device scenario that proves the remediation works
```

Use precise file-and-line references. Do not report an issue solely because a
comment or planning document mentions it; trace executable code. Also list
positive controls already present, but do not let them reduce the severity of a
confirmed release-blocking issue.

## Completion checks

- Run `flutter analyze` and `flutter test` if the environment can complete
  them. Report a timeout, missing SDK, or device dependency accurately.
- Do not inspect or expose the contents of `.env`.
- Do not change `repomix-output.xml`; it is generated output.
