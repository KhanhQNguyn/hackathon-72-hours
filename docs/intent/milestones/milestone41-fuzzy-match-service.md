# Milestone 41 — `fuzzy_match_service.dart`

**One-line goal:** provide a cheap, fast first line of defense that matches applicant values against field labels via string similarity, before falling back to the more expensive OpenAI matching call.

## Project context
`06-plan.md` C2: matches STT n-best hypotheses and any saved applicant-profile fields against detected form fields (e.g. using string-similarity/edit-distance on label text) before falling back to the OpenAI matching call — first line of defense against transcription distortion and label-text variance across sites.

## Maps to plan.md task(s)
C2

## Preconditions
Shape-only dependency on milestone 32 (applicant profile fields) and milestones 10/11 (field labels)

## Files touched
- `lib/services/fuzzy_match_service.dart` — edit

## Implementation spec
- `String? bestMatch(String value, List<String> candidateLabels)`: use a Levenshtein-based similarity ratio. **Threshold: 0.6 similarity** to accept a match (same numeric convention as the project's other thresholds for consistency, though this is a different underlying metric than confidence scores).
- This runs **before** milestone 39's OpenAI matching call — it's the cheap fallback-avoidance step, primarily for matching STT n-best alternatives and saved-profile field values against label text (not for the heuristic DOM-candidate narrowing itself, which is milestones 10/11's job).

## Definition of Done
- [ ] `bestMatch("phone", ["Số điện thoại", "Email", "Tên"])` returns `null` — deliberately testing the cross-language case where plain string similarity should **not** succeed, confirming the fallback to milestone 39's AI call is genuinely necessary and this method isn't silently over-claiming a match
- [ ] `bestMatch("emails", ["Email", "Tên", "Địa chỉ"])` returns `"Email"` (small typo/plural tolerance)

## Size
S
