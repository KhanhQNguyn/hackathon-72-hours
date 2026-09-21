# Milestone 32 — `applicant_profile_service.dart` real storage

**One-line goal:** persist the reusable applicant profile (name, phone, email, CV file path) using the project's three-way storage split — structured fields in `sqflite`, sensitive PII in `flutter_secure_storage`.

## Project context
`02-spec.md` §8: *"Three mechanisms for three different needs, not one catch-all"* — `sqflite` for the structured profile, `flutter_secure_storage` specifically for sensitive PII fields (email, phone) within it, `SharedPreferences` for simple settings only. This milestone builds the `sqflite`/`flutter_secure_storage` half of that split.

## Maps to plan.md task(s)
B4 (part 2 of 3)

## Preconditions
None

## Files touched
- `lib/services/applicant_profile_service.dart` — edit

## Implementation spec
- **`sqflite`:** one table `applicant_profile`, single row with `id` fixed at `1` (there's only ever one applicant on this device — no multi-profile support, per `02-spec.md` §8). Columns: `name TEXT`, `cv_file_path TEXT`.
- **`flutter_secure_storage`:** two separate keys, `applicant_email` and `applicant_phone` — stored apart from the `sqflite` row per the three-way split.
- `Future<Map<String, String>?> getProfile()`: reads the `sqflite` row (returns `null` if no row exists yet — first run), merges in the two secure-storage values (also independently nullable — a user may have set a name but not yet an email).
- `Future<void> saveProfile(Map<String, String> profile)`: upserts the `sqflite` row (`name`, `cv_file_path`) and writes the two secure keys, in that order. If the secure-storage write fails partway, the `sqflite` row is still valid — partial-save is acceptable here since each field is independently useful; don't attempt an all-or-nothing transaction across two different storage engines, which isn't straightforwardly possible anyway.

## Definition of Done
- [ ] `saveProfile({name: 'A', email: 'a@b.com', phone: '0900', cvFilePath: '/x.pdf'})` followed by `getProfile()` returns all four fields correctly, across an app restart
- [ ] `getProfile()` on first run (no data saved yet) returns `null`, not a crash

## Size
M
