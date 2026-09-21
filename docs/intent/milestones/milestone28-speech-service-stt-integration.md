# Milestone 28 — `speech_service.dart` real STT integration

**One-line goal:** wire up real speech-to-text with locale pinning, confidence scoring, and n-best alternatives — the actual voice input the entire app depends on.

## Project context
`02-spec.md` §6 item 1 ("Voice Command Intake"): pin STT locale explicitly per session (`vi-VN`/`en-US`, driven by the language preference), use constrained command phrasing, check confidence score before forwarding to the LLM, pass the n-best hypothesis list downstream.

## Maps to plan.md task(s)
B3 (part 1 of 3)

## Preconditions
Milestone 04

## Files touched
- `lib/services/speech_service.dart` — edit
- `lib/services/preferences_service.dart` — edit (needs `getLanguagePref()` implemented — small enough to fold in here rather than block on milestone 31)

## Implementation spec
- `Future<VoiceCommandResult> listen()`: use the `speech_to_text` package's `SpeechToText().listen(localeId: ..., ...)`, where `localeId` is `'vi_VN'` if `PreferencesService.getLanguagePref() == 'vi'`, else `'en_US'`.
- Constrained phrasing: the UI should prompt with an example phrase rather than accepting fully open-ended speech (exact wording is milestone 42's job; this milestone just needs the plumbing to support a prompt hint being shown).
- Populate `VoiceCommandResult(transcript, confidence, alternatives)` from the plugin's `SpeechRecognitionResult`: `alternatives` from `result.alternates.map((a) => a.recognizedWords).toList()`.

## Definition of Done
- [ ] On a real device, speaking a short phrase returns a `VoiceCommandResult` with a plausible transcript, a confidence value in `[0.0, 1.0]`, and at least one alternative when the plugin provides them
- [ ] Locale actually switches between `en_US`/`vi_VN` based on `PreferencesService.getLanguagePref()` — verify by toggling the pref and checking the plugin receives the updated `localeId` on the next call

## Size
M
