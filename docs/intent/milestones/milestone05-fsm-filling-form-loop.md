# Milestone 05 — FSM: `FillingForm` per-field confirm loop

**One-line goal:** implement the field-by-field confirm loop so the FSM only reaches `FinalReview` once every detected form field has been individually confirmed — never a single fill-everything-then-readback pass.

## Project context
`job_access_assist`'s form-fill was deliberately redesigned from "fill everything silently, read back once at the end" to a field-by-field confirm loop: for each field, the AI announces it, offers a saved value or asks for a new one, gets confirmation, *then* moves to the next field. Full background: `01-intent.md` §4, `02-spec.md` §5–§6.

## Maps to plan.md task(s)
B1 (part 2 of 5)

## Preconditions
Milestone 04 (`FillingFormState(currentFieldId, remainingFieldIds)` must already exist)

## Files touched
- `lib/orchestration/application_flow_fsm.dart` — edit
- `test/orchestration/application_flow_fsm_test.dart` — edit

## Implementation spec
- `FieldConfirmed(String fieldId)` event (already stubbed from scaffolding) received while in `FillingFormState(currentFieldId, remainingFieldIds)`:
  - If `remainingFieldIds` is non-empty: transition to `FillingFormState(currentFieldId: remainingFieldIds.first, remainingFieldIds: remainingFieldIds.skip(1).toList())`.
  - If `remainingFieldIds` is empty: transition to `FinalReviewState()` (fire the already-stubbed `AllFieldsConfirmed` event internally on the way, if useful for other listeners, but the state transition itself doesn't require it).
- **Guard against the exact failure mode this loop exists to prevent:** a `FieldConfirmed(fieldId)` event where `fieldId != currentFieldId` must be a no-op (log a warning), never accidentally advance past the field actually being confirmed.
- This is the concrete mechanism behind `02-spec.md` §5's statement: "the FSM does not move to `FinalReview` until every field has been individually confirmed."

## Definition of Done
- [ ] Unit test: `FillingFormState('name', ['phone', 'email'])` + `FieldConfirmed('name')` → `FillingFormState('phone', ['email'])`
- [ ] Unit test: `FillingFormState('email', [])` + `FieldConfirmed('email')` → `FinalReviewState()`
- [ ] Unit test: `FillingFormState('name', ['phone'])` + `FieldConfirmed('phone')` (wrong field id) → state unchanged, no advance

## Size
M
