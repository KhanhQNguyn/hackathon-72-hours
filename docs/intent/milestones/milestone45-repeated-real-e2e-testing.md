# Milestone 45 — Repeated real end-to-end testing

**One-line goal:** run the full real flow repeatedly against the real target, surfacing and fixing every failure mode mocked testing couldn't catch.

## Project context
`06-plan.md` C5: once Workstream A + B are integrated (post-Integration Checkpoint), run repeated real end-to-end tests against the real target platform, logging every failure mode (wrong content read, form field not found/mismatched, page/PDF parse failure) and feeding fixes back to A/B/C as needed.

## Maps to plan.md task(s)
C5

## Preconditions
Milestone 44

## Files touched
None as a fixed set — fixes this surfaces route back to whichever earlier milestone owns that code. This is a testing/iteration milestone, not a build-one-thing milestone.

## Implementation spec
- Run the full real flow (trigger → listing read → PDF read → field-by-field fill → `FinalReview` → submit-confirmed → `Done`) repeatedly against the real chosen target, logging every failure.

## Definition of Done
- [ ] At least 3 consecutive full runs complete without an unrecovered error, **or** every remaining failure is triaged with a specific milestone/bug reference — not left as an unexplained flake
- [ ] The CAPTCHA path (milestones 13/14) and at least one error-recovery path (milestones 22/23) are each exercised at least once during this testing, not just the happy path

## Size
L — open-ended by nature. This is real-world iteration, not a fixed-scope build task; budget accordingly rather than expecting a fixed session count to finish it.
