# Verification audit — response to `AUDIT.md`

Date: 2026-09-22. Working tree at commit `48f79fd` ("update UI"). **No source
file was modified**; this document is the only file written.

Safe checks run:

- `flutter analyze` → **3 errors** (finding 1). Full completion.
- `flutter test` → 169 passed; **4 test files fail to load** because `lib/`
  does not compile (finding 1): `test/ui/accessibility_test.dart`,
  `test/ui/home_screen_test.dart`, `test/ui/mic_button_and_platform_test.dart`,
  `test/widget_test.dart`. So the suite is currently **not** proof that the UI
  works.
- `.env` was **not** opened. Only whether it exists and is non-empty was
  checked (it exists, non-empty, untracked, never in `git log --all`).
- No APK was built, so "the key is in the artifact" is proven from the build
  inputs, not by unzipping an artifact.

Findings are in priority order. Finding 1 is not in `AUDIT.md`, but it stops
every other fix from being testable, so it is first.

---

## [Critical] The working tree does not compile

Status: Confirmed

Evidence:
- `lib/core/theme.dart:88` — `inputBorder.copyWith(side: BorderSide(...))`
  where `inputBorder` is an `OutlineInputBorder` (`theme.dart:48`).
  `OutlineInputBorder.copyWith` takes `borderSide:`, not `side:` (`side:` is
  `RoundedRectangleBorder`'s, used correctly at `theme.dart:80`).
- `lib/core/theme.dart:89`, `:90` — the same mistake for `focusedBorder` and
  `errorBorder`.
- `flutter analyze` → 3 × `undefined_named_parameter` at those lines.
- Because `theme.dart` is imported by the app root, `flutter test` reports
  4 files "loading … [E]".

Impact:
- `flutter run` / `flutter build apk` fail. Nothing below can be exercised on
  a device until this is fixed. It also hides regressions in the UI tests.

Recommendation:
- Rename the three keyword arguments to `borderSide:`. One-line-each change.

Validation:
- `flutter analyze` clean; `flutter test` loads all files (previously 196
  passing before the theme commit).

---

## [Critical] OpenAI API key is shipped inside the Android artifact

Status: Confirmed (from build inputs; artifact not unpacked — needs an APK
build to demonstrate byte-for-byte)

Evidence:
- `pubspec.yaml:91` — `- .env` is listed under `flutter: assets:`. Flutter
  copies every listed asset into the APK/AAB as
  `assets/flutter_assets/.env`, **as plain text**. `.gitignore:49` only keeps
  it out of Git; it does not keep it out of the build.
- `lib/main.dart:12` — `await dotenv.load(fileName: '.env')` reads it from that
  bundled asset at runtime, so the asset must be present.
- `lib/services/openai_service.dart:176-178` — the key is read from
  `dotenv.env['OPENAI_API_KEY']` on each call.
- `lib/services/openai_service.dart:423` — it is sent from the phone as
  `Authorization: Bearer …` straight to `api.openai.com`
  (`openai_service.dart:159`).
- `.env` exists locally and is non-empty (contents not inspected). It was never
  committed (`git log --all -- .env` is empty; `git ls-files` does not track
  it), and `repomix-output.xml` contains no `sk-…` token.
- `android/app/build.gradle.kts:34-38` — the release build is signed with the
  **debug** key and has no shrinking/obfuscation configured. Obfuscation would
  not help anyway: an asset is not code.

Impact:
- A release **or debug** APK/AAB contains the key. Anyone with the file
  (`unzip app-release.apk assets/flutter_assets/.env`) gets it. Practical
  consequence: unbounded spend on the account and use of the account for
  anything else the key allows. `02-spec.md` §3 records this as an accepted
  hackathon risk; it is release-blocking for anything distributed beyond the
  team. The current team habit of "send the APK to teammates" already
  distributes it.
- `--dart-define` is not a fix: those values are also embedded in the compiled
  app and extractable.

Recommendation:
- Production: remove `.env` from `assets:` and call OpenAI through a small
  server-side proxy (Cloud Run/Worker/Lambda) that holds the key, applies
  per-install rate/spend limits and an allow-list of the five call shapes, and
  authenticates the app with Play Integrity / a short-lived signed token
  (minted per session, minutes of lifetime, scoped to the proxy). The app then
  holds no OpenAI credential.
- Interim for the hackathon: use a dedicated project key with a hard monthly
  budget and model allow-list; never distribute a build made with the personal
  key; rotate after the event; make CI/`flutter build` fail if `.env` is in the
  asset list (a one-line grep step).

Validation:
- Build a release APK, `unzip -l app-release.apk | grep -i env` → no match;
  `strings` over the APK for the key prefix → no match. Proxy rejects a request
  without a valid session token and rejects a model/endpoint outside the
  allow-list.

---

## [Critical] A default build ships the fake WebView/PDF and announces a fake success

Status: Confirmed

Evidence:
- `lib/core/app_config.dart:10-13` — `useMockServices` is
  `bool.fromEnvironment('USE_MOCK_SERVICES', defaultValue: true)`. A plain
  `flutter run` or `flutter build apk --release` (no `--dart-define`) is mock
  mode.
- `lib/app.dart:69` and `:75` — in mock mode `FakeWebViewControllerService()`
  and `FakePdfReaderService()` are constructed.
- `lib/app.dart:6-7` — the mocks are imported by production code, so they are
  compiled into the release binary regardless of the flag.
- Mock submit: the fake `clickElement` returns `true`, the FSM enters
  `DoneState` (`application_flow_fsm.dart:171-172`) and the flow narrates
  "Your application has been submitted." for a canned "Example Co" page.
- `android/app/build.gradle.kts:34-38` — release is debug-signed; no flavors;
  no `.github/` or other CI, no README/build docs that mention the define
  (`README.md` is the old artifact-chain text). Only `CLAUDE.md:16` documents
  it.

Impact:
- A build made the normal way lets a blind user "apply" to a job that does not
  exist and hear that the application was submitted. That is a false statement
  about a consequential real-world action, delivered through a channel the user
  cannot visually cross-check.

Recommendation:
- Invert the default: `defaultValue: false`, and refuse mock in release:
  `assert(!(kReleaseMode && useMockServices))` plus a hard runtime guard that
  throws at startup. Keep the demo path as an explicit
  `--dart-define=USE_MOCK_SERVICES=true` (or a `mock` flavor) and, whenever mock
  is on, show a persistent "DEMO — nothing is sent" banner and speak it once so
  a screen-reader user is told too.
- Move the fakes out of the shipped import graph (`lib/mocks/` behind a
  conditional import or into `test/` + a dev-only entry point such as
  `lib/main_mock.dart`).

Validation:
- Unit test asserting `AppConfig.useMockServices == false` when no define is
  passed (today the default-`true` is what the widget tests rely on, so they
  would need `App(useMockServices: true)` explicitly). A release-mode test
  (`flutter test --release` or a `const bool.fromEnvironment` check in CI) that
  fails if mock is reachable. CI step: `flutter build apk --release` then grep
  the APK for the string `Example Co` — must be absent.

---

## [High] The app does not bind a listing, its application page and its form

Status: Confirmed (statically). Site behaviour: needs live target site.

Evidence:
- `lib/core/app_config.dart:17-20` — `targetUrl` defaults to
  `https://www.vietnamworks.com`, the **homepage**.
- `lib/orchestration/application_flow_controller.dart:504` — the only
  navigation is `webView.loadTarget(AppConfig.targetUrl)`. There is no code
  that identifies a particular listing, finds an "Apply" control, clicks it, or
  waits for and verifies a second page (grep: no such call anywhere).
- `application_flow_controller.dart:335` (and `:341`) — `readDom()` reads that
  first page once; `:361` — `_fields = _formFields(dom)` takes the fields from
  **that same, pre-PDF snapshot**.
- `application_flow_controller.dart:631-660` — `_readForm()` only narrates the
  PDF text/sections. `PdfStructure.inferredFields` (returned by the AI) is never
  read anywhere; the PDF does not influence which fields are filled. So a
  user-selected PDF is read aloud while the fields come from the previously
  loaded page — exactly the concern raised.
- `assets/js/dom_reader.js:261` — `getLabeledFields` takes **every**
  `input, select, textarea` on the page; only search-scored inputs are skipped.
  There is no visibility filter for these (the visibility helper at `:285` is
  used only by CAPTCHA detection).
- `application_flow_controller.dart:557-577` — the only extra filter drops
  `hidden/submit/button/image/reset/checkbox/radio`, and the search/submit
  candidate ids. Login email/**password**, newsletter email, phone-number and
  coupon inputs on a homepage all survive.

Impact:
- On the default target the flow would ask the user for the values of the
  site's own login and newsletter boxes and type them there, then "submit" via
  the top heuristic button. Even on a real listing page, an in-page apply form
  that is actually in a modal/second page is never reached. The PDF gives the
  user false assurance ("I read your form") that it matches what is filled.
  Invisible (`display:none`) inputs — including honeypot fields designed to
  catch bots — are also treated as fields.

Recommendation (smallest credible design):
1. Introduce a `ListingTarget { listingUrl, applyUrl?, expectedHost,
   formFingerprint? }`. The user (or a later search step) chooses the listing;
   `AppConfig.targetUrl` becomes a fallback for demos only.
2. Flow: load `listingUrl` → read it → find the apply control from the
   heuristic candidates using the existing element-match call (≥ 0.7 or ask the
   user) → click → wait for navigation/stable → **verify** the new document:
   same `expectedHost`, and a form containing ≥ 2 recognisable applicant fields
   (name/email/phone/file) → only then read fields.
3. Fingerprint the form at `ListingConfirmed` (URL path, form element, set of
   field ids/labels) and re-check it before every fill and before submit;
   abort with a spoken error if URL/origin/form changed.
4. Restrict discovery to inputs inside the verified `<form>` (or its nearest
   container), visible only; exclude the sensitive set (next finding).
5. Treat the PDF as **reference**: reconcile `inferredFields`/AcroForm names
   against DOM labels and tell the user about mismatches before filling.

Validation:
- Fixture pages: (a) homepage with login + newsletter + search → flow refuses
  ("this is not an application form") and fills nothing; (b) listing → apply
  click → form page → only that form's fields are asked; (c) form whose host
  changes mid-flow → aborts; (d) PDF listing an extra field that the DOM lacks
  → mismatch narrated. Live: repeat against the real listing (needs device).

---

## [High] "Submitted" is announced after a JavaScript `.click()`, not after acceptance

Status: Confirmed

Evidence:
- `assets/js/form_filler.js:86-91` — `__formFiller_clickElement` calls
  `el.click()` and returns `{success: true}`. It reports that the click was
  invoked, nothing else.
- `application_flow_controller.dart:963-965` — `clickElement` returning `true`
  is the only success criterion; it returns from `submitApplication()`.
- `lib/orchestration/application_flow_fsm.dart:171-172` — `await
  _performRealSubmit(); _setState(const DoneState());` — the FSM enters `Done`
  as soon as that call returns without throwing.
- `application_flow_controller.dart:427-428` — `DoneState` → narrates
  "Your application has been submitted."
- No code inspects the page after the click: no wait, no validation-error scan
  (`aria-invalid`, `[role=alert]`), no navigation/URL check, no success-text
  check, no HTTP status observation (grep for post-submit handling: none).

Impact:
- A required field the site rejects, a server 4xx/5xx, a CAPTCHA that appears on
  submit, a silent client-side validation block, or a click on the wrong
  button (e.g. "Save for later") is announced as a completed application. The
  user, who cannot see the page, will not apply again.

Recommendation — post-submit contract:
- Replace `DoneState` entry with an explicit outcome: `SubmitOutcome ∈
  {accepted, rejected(errors), unknown}` produced by a new
  `verifySubmission(before)` step.
- Capture `before` = {URL, form present, field values}. After the click, wait
  for stable (existing settle-wait, bounded ~10 s) and evaluate **independent**
  conditions: (a) URL/route changed to a confirmation pattern (`thank`,
  `success`, `confirmation`, `applied`, `ứng tuyển thành công`) **or** a
  visible success region (`role=status/alert`, known EN/VI phrases such as
  "đã ứng tuyển", "application submitted", "thank you") **and** the submitted
  form is gone; (b) no `aria-invalid`/error region present. Optionally corroborate
  with WebView HTTP status callbacks for the submit navigation.
- `accepted` → `SubmissionVerified` event → `DoneState` → "submitted".
  `rejected` → read the site's error text aloud and return to `FinalReview`
  (edit loop). `unknown` → never say "submitted": "I pressed submit but could
  not confirm it went through — please check the page or try again", and offer
  voice retry.
- FSM change: `Done` reachable only via `SubmissionVerified`.

Validation:
- Fixtures: success page, validation-error page, unchanged page (silent no-op),
  server-error page, redirect to login. Assert the narration never contains
  "submitted" except for the first. Live: submit a deliberately invalid form on
  the real target and confirm it is reported as rejected (needs device + site).

---

## [High] Sensitive fields can be requested, read aloud, displayed and logged

Status: Confirmed

Evidence:
- No blocking anywhere: `grep -rniE "password|passcode|otp|autocomplete|cc-number|redact|mask"`
  over `lib/` and `assets/` returns nothing.
- `assets/js/dom_reader.js:261-273` — discovery returns every input with only
  `type`, label and id. `autocomplete`, `name`, `id` and `inputmode` are not
  collected, so even a downstream filter would have nothing to key on beyond
  `type`/label.
- `application_flow_controller.dart:557-577` — the filter does not exclude
  `password`, `tel`-vs-otp, or any sensitive name/label. A `type="password"`
  field is therefore a normal field.
- Requested: `_collectValue` (`:786`, `:796`) asks by label for any field.
- Read aloud: `:805` `confirmValue(label, value)` speaks the typed/said value
  back; `:917-920` `_summary()` speaks **every** value in the final review;
  `:786` `offerSaved` speaks saved profile values (email, phone).
- Displayed: each spoken line is mirrored into `lastNarration` and shown on
  screen (`StatusNarrationView`).
- Logged: `lib/services/tts_service.dart:44` logs
  `tts: speak(...) "<the exact text>"` for every utterance — including all
  values above. `lib/orchestration/voice_command_gate.dart:106` logs the
  rejected transcript (a mis-heard secret would be logged).
- Retained: `_values` (`application_flow_controller.dart:216`-ish) holds every
  value for the run (cleared only at the next `start()`).
- Sent externally: **no field value is sent to OpenAI** (element matching sends
  only id/tag/type/role/label/score — `element_matching_prompt.dart:21-29`).
  But the visible page text (`summarizeListing`, may include a signed-in user's
  name/email in the header), the PDF text (`structurePdf`, may be a filled
  document) and the spoken command are sent, and the "edit <words>" target goes
  to the matcher. Also `defaultImageFetcher` (next finding).

Impact:
- A password/OTP/card/ID field on a page (a login box on a homepage, a
  payment step, an "identity number" question) would be asked out loud in
  public, echoed back, shown on screen, written to device logs, and included in
  the final read-through.

Recommendation:
- Collect `autocomplete`, `name`, `id`, `inputmode`, `maxlength` in
  `dom_reader.js` and classify each field: **sensitive** if any of —
  `type` ∈ {`password`}; `autocomplete` starts with `current-password`,
  `new-password`, `one-time-code`, `cc-`; name/id/label matches (EN+VI,
  case/diacritic-insensitive) `pass(word)?|mật khẩu|otp|passcode|mã xác thực|
  mã bảo mật|pin|cvv|cvc|card|thẻ|số thẻ|iban|tài khoản ngân hàng|
  security (question|answer)|câu hỏi bảo mật|ssn|social security|tax id|
  mã số thuế|cmnd|cccd|căn cước|passport|hộ chiếu|national id|số định danh`.
- For a sensitive field: do **not** collect by voice, do not read back, do not
  store. Say once "this field needs private entry; I'll move focus to it" and
  hand off: focus the element (Feature 2 mechanism) so the user types with the
  TalkBack keyboard, and continue on "continue" (same pattern as CAPTCHA). If
  the field is required and cannot be handled privately, stop with a spoken
  explanation instead of skipping silently.
- Final review: show/say a mask (`••••` / "entered privately") for any
  sensitive or unknown-type-but-flagged field; never the value.
- Logging: stop logging utterance text (`tts_service.dart:44` → log length and
  language only); redact transcripts in `voice_command_gate.dart:106`; guard
  with `kReleaseMode`.
- Clear `_values` when the run ends; do not put values in `lastNarration`.
- AI payloads: strip emails/phone-like/long-digit strings from `pageText`
  and the PDF text before sending, and gate the calls behind consent (below).

Validation:
- Fixture with password, OTP, card and CCCD inputs: assert none is asked,
  read, logged or summarised in clear, and that the summary contains only masks;
  test that `Logger` output for a full run contains no field value (capture the
  `developer.log` stream). Device: verify TalkBack hand-off to the field.

---

## [Medium] Image fetch has no bound, MIME or origin policy, and no consent

Status: Confirmed

Evidence:
- `application_flow_controller.dart:57-80` `defaultImageFetcher`:
  - `data:` URIs — `:59-66` decode the whole payload with `base64Decode(...)`
    **before any size check**; there is no decoded-byte limit (the 4 MB limit at
    `:71` applies only to the `http` branch).
  - MIME is taken verbatim from the `data:` header (`:65`) or the response
    header, defaulting to `image/png` when absent (`:74-75`); no allow-list, no
    magic-byte check.
  - HTTP branch: `http.get(...)` (`:68-70`) buffers the **entire** body in
    memory, then checks `bodyBytes.length` (`:71`) — the limit is applied after
    the memory is spent. The 10 s timeout bounds time, not bytes. Redirects are
    followed automatically.
  - No scheme or origin policy: any URL from the page's `<img src>`
    (`dom_reader.js:31-40`) is fetched by the phone — `http://` (cleartext),
    localhost, LAN/private addresses, third-party hosts.
- `:611-612` — up to 3 images without alt text are fetched and, on success,
  base64-encoded and sent to `gpt-4o` (`openai_service.dart` `imageToText`).
- No consent or disclosure anywhere (`grep consent|disclos|privacy` in `lib/`
  finds only a prompt string).

Impact:
- Memory pressure/OOM from a hostile or accidentally huge image or data URI
  (a few hundred MB `data:` string is already in the page and gets doubled by
  the decode). Unexpected requests from the user's device/network to arbitrary
  or internal hosts (tracking beacons reveal the user's IP and that they are
  reading this listing; LAN probing). Page imagery — which on a logged-in page
  can include the user's own documents/avatar — is uploaded to a third party
  without the user being told.

Recommendation:
- Bounded decoding: reject a `data:` URI whose base64 length exceeds
  ~5.4 MB **before** decoding; for HTTP use `Client.send` and count streamed
  bytes, aborting at 4 MB; set `Accept: image/*`.
- Validate: `https` only; host on the listing's registrable domain or a small
  CDN allow-list; reject localhost/private/link-local IPs; re-apply the policy
  to each redirect (`followRedirects: false` + manual hops); require the
  sniffed magic bytes (PNG/JPEG/WebP/GIF) to agree with an allowed MIME.
- Consent: a setting (default **off** for image/page-text/PDF sharing) with a
  one-time spoken disclosure — "To read pictures aloud I send them to OpenAI.
  Allow?" — remembered in preferences; without consent, fall back to the
  existing non-AI path (the flow already degrades correctly).

Validation:
- Unit tests: oversize data URI rejected without allocation, `http://` and
  private-IP URLs refused, redirect to a disallowed host refused, MIME/magic
  mismatch refused, consent off → `imageToText` never called. Device: an
  image-only listing still gets read once consent is given.

---

## [Low] Release configuration and generated-file churn

Status: Confirmed

Evidence:
- `android/app/build.gradle.kts:34-38` — the release build type is signed with
  the debug key and has a `TODO` for a real signing config.
- `flutter test`/`flutter analyze` regenerate
  `macos/Flutter/GeneratedPluginRegistrant.swift`,
  `windows/flutter/generated_plugin_registrant.cc`,
  `windows/flutter/generated_plugins.cmake` (shown modified in `git status`
  after every run) — unrelated noise that will keep conflicting in merges.

Impact:
- A debug-signed "release" cannot be a Play Store artifact; the churn causes
  spurious merge conflicts on teammates' branches.

Recommendation:
- Add a real release signing config before any distribution; add the three
  generated desktop files to `.gitignore` (and `git rm --cached`) since the
  project is Android-only.

Validation:
- `flutter build appbundle --release` succeeds with a keystore; `git status`
  clean after `flutter test`.

---

## Positive controls already present (they do not lower any severity above)

- **Submit is gated by state, not by AI text:** the only call site of the real
  submit is `application_flow_fsm.dart:164-172`, reachable only from
  `FinalReviewState` on `SubmitConfirmed`; the controller fires it only after
  an affirmative spoken reply (`application_flow_controller.dart` final-review
  loop) — verified by tests.
- **Ambiguous element matches ask the user** (< 0.7 confidence) instead of
  acting; hallucinated ids are dropped (`openai_service.dart`, `matchElement`).
- **Tied submit candidates refuse to guess** (`submitApplication`,
  `FlowFailure(errSubmitUnsure)`).
- **AI is optional per step:** without a key every call degrades to non-AI
  behaviour; every service failure surfaces as `OpenAiException`.
- **Only element metadata is sent for field matching**, never field values or
  raw DOM (`element_matching_prompt.dart:21-29`).
- **`.env` is git-ignored and was never committed**; `repomix-output.xml`
  holds no key.
- **WebMessageListener is origin-restricted** to the loaded origin
  (`webview_controller_service.dart`, milestone 17); `INTERNET` and
  `RECORD_AUDIO` are the only manifest permissions requested.
- **Image path already limits volume** to 3 alt-less images per page and
  drops images that have alt text (`application_flow_controller.dart:611`).
- **CAPTCHA is a hard human hand-off** — audio button never counts as solved.
- **Announce-before-chooser** and post-attach verification for CV upload.
- **Android-only guard** shows an explicit message on other platforms.

## Needs a device or live service (not settled here)

- Whether the APK actually contains `assets/flutter_assets/.env` — build one and
  `unzip -l` it (expected yes).
- All real-site behaviour: apply-control detection, form structure, honeypot
  fields, post-submit page — needs the live VietnamWorks target and a phone.
- Whether `developer.log` output reaches logcat in a release build (it does in
  debug/profile); treat the logging finding as real regardless.
- TalkBack focus hand-off for private entry; consent prompt UX.
