# Milestone 33 — Settings-screen applicant-profile fields UI

**One-line goal:** give the user a way to enter/edit their reusable profile fields, so they aren't forced to speak sensitive data like their email over voice every single time.

## ⚠️ Open decision — confirm scope before building this file
Neither `01-intent.md` nor `02-spec.md` says whether `06-plan.md` B4's "host the (optional) reusable applicant-profile fields" actually means a dedicated Settings-screen data-entry UI, or just that the persistence layer (milestone 32) exists and profile fields get captured conversationally the first time they're needed during form-fill (milestone 05's per-field loop already asks the user for a value when no saved one exists — that path could just call `saveProfile()` on the way through, with no separate screen at all).

**This entire milestone assumes the dedicated-UI interpretation.** If the team decides against it, skip this file entirely and fold profile-capture into milestone 05 instead — no new file needed for that alternative.

## Project context
`job_access_assist` — see `01-intent.md`/`02-spec.md` for full background on the applicant profile (name, phone, email, CV file path).

## Maps to plan.md task(s)
B4 (part 3 of 3)

## Preconditions
Milestone 31, milestone 32

## Files touched
- `lib/ui/screens/settings_screen.dart` — edit

## Implementation spec
- Four labeled `TextFormField`s (name, phone, email) plus a "pick CV file" button (reusing `FilePickerService` from milestone 21), with a single "Save" action calling `ApplicantProfileService.saveProfile()`.
- Each field: `Semantics(label: ...)` naming the field in the active UI language, same pattern as milestone 31.
- Pre-populate all fields from `ApplicantProfileService.getProfile()` when the screen opens.

## Definition of Done
- [ ] All four fields save correctly and are pre-populated with the existing profile the next time the screen opens
- [ ] Manual: TalkBack can navigate and fill in all four fields without sighted assistance — dry-run this, don't just trust that the `Semantics` labels compile

## Size
M
