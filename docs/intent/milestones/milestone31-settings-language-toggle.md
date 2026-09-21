# Milestone 31 — `settings_screen.dart` language toggle

**One-line goal:** let the user switch between English and Vietnamese, persisted across app restarts and propagated to STT/TTS immediately.

## Project context
`02-spec.md` §8: `language_pref` (`en`|`vi`) drives STT locale + TTS voice + UI text, stored via `SharedPreferences` — the simplest of the project's three storage mechanisms, since this is genuinely simple, non-sensitive settings data.

## Maps to plan.md task(s)
B4 (part 1 of 3)

## Preconditions
Milestone 04

## Files touched
- `lib/ui/screens/settings_screen.dart` — edit
- `lib/services/preferences_service.dart` — edit (`setLanguagePref`/`getLanguagePref` real `SharedPreferences` implementation)

## Implementation spec
- A `Switch` or two `RadioListTile`s (EN / VI). Each option's `Semantics(label: ...)` names the language **in that language itself** (e.g. "Tiếng Việt", not just "Vietnamese"), so a Vietnamese-speaking screen-reader user recognizes it immediately — per `02-spec.md` §7's labeling requirements.
- On change: call `PreferencesService.setLanguagePref(code)`, and propagate immediately — `SpeechService`/`TtsService` (milestones 28/30) should re-read the preference on their *next* call, not require an app restart.

## Definition of Done
- [ ] Toggling the setting persists across an app restart (`SharedPreferences` round-trip verified)
- [ ] After toggling, the very next `TtsService.speak()` call audibly uses the new language's voice, with no restart needed

## Size
S
