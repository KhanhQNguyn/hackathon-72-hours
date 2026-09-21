# Milestone 06 — FSM: `FinalReview` + `EditingField` loop-back

**One-line goal:** let the user request a correction to a specific already-confirmed field from `FinalReview`, without restarting the whole form.

## Project context
After every field is confirmed (milestone 05), the flow reaches a lightweight `FinalReview` summary — not a full re-read of every field, since each was already confirmed individually. From there, saying "sửa lại [field]" re-collects and re-confirms just that one field, then returns to `FinalReview`. Full background: `01-intent.md` §4, `02-spec.md` §5.

## Maps to plan.md task(s)
B1 (part 3 of 5)

## Preconditions
Milestones 04, 05

## Files touched
- `lib/orchestration/application_flow_fsm.dart` — edit
- `test/orchestration/application_flow_fsm_test.dart` — edit

## Implementation spec
- `FinalReviewState()` + `EditFieldRequested(String fieldId)` (already stubbed) → `EditingFieldState(fieldId)` (already stubbed).
- `EditingFieldState(fieldId)` + `FieldEditConfirmed` (already stubbed) → back to `FinalReviewState()` — **exactly this loop-back, never to `FillingFormState`**, since the other already-confirmed fields' values must not be touched or re-asked.
- `FinalReviewState()` + `SubmitConfirmed` is deliberately **not** implemented in this milestone — that's milestone 07's job, kept separate so the FSM-gating reliability principle gets its own focused tests.

## Definition of Done
- [ ] Unit test: `FinalReviewState()` + `EditFieldRequested('phone')` → `EditingFieldState('phone')`
- [ ] Unit test: `EditingFieldState('phone')` + `FieldEditConfirmed` → `FinalReviewState()`
- [ ] Unit test: this loop-back can happen twice in a row for two different fields (edit phone, return to review, edit email, return to review) without ever entering `FillingFormState` — mirrors `01-intent.md` §4's "any point before submitting" language

## Size
M
