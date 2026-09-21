# Milestone 42 — Narration script content (EN + VI)

**One-line goal:** write the actual phrases spoken at every point in the flow, in both English and Vietnamese — directly affects how clean the final recorded demo sounds.

## Project context
`06-plan.md` C3: keep phrasing short and unambiguous. Several exact strings are already fixed verbatim elsewhere and must be reused, not rephrased: the CAPTCHA hand-off narration (`01-intent.md` §4) and the page-load-retry narration (`02-spec.md` §3).

## Maps to plan.md task(s)
C3

## Preconditions
Milestones 04–08 (state/event names must be final before writing narration keyed to them)

## Files touched
- `lib/core/narration_lookup.dart` — edit (completes the placeholder stub referenced in milestone 26)

## Implementation spec
Minimum required set of narration strings, each in EN and VI, keyed by state/event (derived directly from states/events already named in milestones 04–08, 13/14, 29):
- `Listening` — prompt for a command (should reference the constrained phrasing pattern, e.g. "Order [item] on Shopee"-style short utterance, adapted to this project's domain: "Say something like 'read this listing' or 'apply to this job'")
- `ParsingIntent` / `LoadingTarget` / `ReadingContent` — progress narration, e.g. *"Reading the job description..."*
- Field-fill announcement template: *"Filling in your {fieldLabel}..."*
- `FinalReview` summary template
- CAPTCHA narration — reuse **exactly**, verbatim, from `01-intent.md` §4: *"Có CAPTCHA ở đây, bạn giải giúp tôi rồi nói 'tiếp tục' nhé"*
- Error/retry narration — reuse **exactly**, verbatim, from `02-spec.md` §3: *"that didn't load as expected, retrying..."*
- STT re-prompt (milestone 29) and element-match disambiguation (milestone 39) templates — the EN wording is already drafted in those milestones; this file supplies the paired Vietnamese wording
- Field-not-found narration (milestone 24): *"This form doesn't seem to have a field for [X] — skipping it"* + VI equivalent

## Definition of Done
- [ ] Every state/event from milestones 04–08 and 13/14 that the FSM actually narrates has both an EN and a VI string in `narration_lookup.dart`
- [ ] A native or fluent Vietnamese speaker on the team reviews the VI strings for naturalness before the final recording — per `06-plan.md` C3's own note that phrasing "directly affects how clean the final recorded demo sounds"

## Size
M
