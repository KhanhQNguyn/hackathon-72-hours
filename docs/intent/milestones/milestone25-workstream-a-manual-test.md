# Milestone 25 — Workstream-A manual test against the real target

**One-line goal:** prove Workstream A's pieces (DOM reading, form filling, PDF parsing) work together against the real chosen target, in isolation from B/C, before full-app integration.

## Project context
`06-plan.md` A6: end-to-end manual test against the chosen real target listing and PDF sample, run before the Integration Checkpoint (milestone 44) — driven from a debug harness, not the full app UI, to isolate Workstream-A bugs from B/C bugs.

## Maps to plan.md task(s)
A6

## Preconditions
Milestones 09–21 (all of Workstream A's building-block milestones)

## Files touched
None — this is a manual testing milestone; findings route back to whichever earlier milestone's code needs fixing.

## Implementation spec
- Run milestones 09–21's pieces end-to-end against the real chosen target listing/PDF (once picked per `01-intent.md` §7), driven from `milestone01`'s debug harness (extend it as needed) rather than the full app UI.

## Definition of Done
- [ ] `readDom()` against the real listing page returns correctly-populated search/submit/labeled-field candidates
- [ ] `fillField()` against a real form field on that page succeeds, and the value visibly appears filled when viewed inside the WebView
- [ ] `extractTextWithOcrFallback()` against the real chosen PDF sample returns usable text
- [ ] Findings are logged (what worked cleanly vs. what needed a fix) — this feeds directly into milestone 44's Integration Checkpoint

## Size
M
