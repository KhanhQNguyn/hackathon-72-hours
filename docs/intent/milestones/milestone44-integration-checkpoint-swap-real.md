# Milestone 44 — Integration Checkpoint: swap mocks for real services

**One-line goal:** point the app at Workstream A's real `WebViewControllerService`/`PdfReaderService` instead of the mocks from milestone 34, and see what breaks when the pieces first meet reality.

## Project context
`06-plan.md`'s own named "Integration Checkpoint" — *"the point where Workstream A's real DOM/PDF-reading and form-filling output, Workstream B's FSM/UI, and Workstream C's AI layer first run together against a real job portal and a real PDF application form... the sooner real integration starts, the more time remains to fix what it surfaces."*

## Maps to plan.md task(s)
B7

## Preconditions
Milestone 12, milestone 16, milestones 18–21 (all real A services), milestone 35 (mocked flow already proven)

## Files touched
- `lib/app.dart` — edit (the same injection point from milestone 35, now pointing at real `WebViewControllerService`/`PdfReaderService`)

## Implementation spec
- No new logic in this milestone — a dependency-injection swap, plus whatever bugs it surfaces. This is a "run it and see" milestone, not a "write new code" one.

## Definition of Done
- [ ] The exact same manual run from milestone 35's Definition of Done now completes using real `WebViewControllerService`/`PdfReaderService` against the real target, not fakes
- [ ] Every bug this surfaces is logged and routed back to the specific earlier milestone whose contract it violates — not patched ad hoc directly in `app.dart`

## Size
M
