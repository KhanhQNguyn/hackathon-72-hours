# Milestone 24 — Error handling: form field not found

**One-line goal:** when a form simply doesn't have a field the flow needs to fill, skip it gracefully with a clear explanation — this is a distinct case from a low-confidence match, and retrying won't produce a field that isn't there.

## Project context
This is deliberately **not** the same as milestone 39's low-confidence disambiguation (which asks the user to choose among several plausible candidates). This milestone covers the **zero-candidates** case: the heuristic pre-filter (milestones 10/11) returns no candidates at all for a field type the flow was asked to fill (e.g. the applicant profile has a phone number, but this particular application form has no phone field).

## Maps to plan.md task(s)
A5 (part 3 of 3)

## Preconditions
Milestone 08, milestone 39 (needs the AI matching call's "no candidates" outcome shape to exist first)

## Files touched
- `lib/orchestration/application_flow_fsm.dart` — edit

## Implementation spec
- Given a `DomSnapshot` with zero labeled fields matching a requested field type: narrate a distinct message — *"This form doesn't seem to have a field for [X] — skipping it"* (English shown; pair with the Vietnamese equivalent from milestone 42) — then advance past that field in the per-field loop (as if it had been confirmed with no value), rather than entering `ErrorState`/`RetryingState`. Retrying achieves nothing here since the field genuinely doesn't exist on this form.

## Definition of Done
- [ ] Given a `DomSnapshot` with zero labeled fields matching a requested field type, the flow narrates the "doesn't seem to have a field" message and advances to the next field in the per-field loop, without entering `ErrorState`

## Size
S
