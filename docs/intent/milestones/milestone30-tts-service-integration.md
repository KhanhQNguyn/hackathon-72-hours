# Milestone 30 — `tts_service.dart` real TTS integration

**One-line goal:** wire up real text-to-speech narration, ensuring utterances play sequentially rather than overlapping.

## Project context
Every step the flow takes is spoken through `TtsService`, never silently — this is the app's primary output channel and needs to be reliable before any of the narration content (milestone 42) can be meaningfully tested.

## Maps to plan.md task(s)
B3 (part 3 of 3)

## Preconditions
Milestone 04

## Files touched
- `lib/services/tts_service.dart` — edit

## Implementation spec
- `Future<void> speak(String text)`: use the `flutter_tts` package. `setLanguage('vi-VN')` or `setLanguage('en-US')` based on `PreferencesService.getLanguagePref()`. Call `awaitSpeakCompletion(true)` so callers can reliably sequence narration steps without overlap — important for the field-by-field loop's turn-taking (announce field → wait → listen for confirmation).

## Definition of Done
- [ ] Calling `speak()` twice in quick succession on a real device produces two sequential, non-overlapping utterances — verifies `awaitSpeakCompletion` is actually taking effect, not just set and ignored

## Size
S
