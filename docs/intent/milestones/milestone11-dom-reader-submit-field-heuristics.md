# Milestone 11 — `dom_reader.js`: submit-button and labeled-field candidate heuristics

**One-line goal:** extend the same heuristic-narrowing approach from milestone 10 to submit buttons and general labeled form fields.

## Project context
Same two-stage heuristic-filter-then-AI-rank design as milestone 10 (see `02-spec.md` §5). This milestone covers the other two element categories Feature 1 needs to locate: the submit button (checkpoint 2) and every other labeled form field (name, phone, email, etc.) for the field-by-field fill loop.

## Maps to plan.md task(s)
A2 (part 3 of 4)

## Preconditions
Milestone 09 (reuses the `data-app-node-id` tagging approach from milestone 10 — build that milestone first, or at minimum use the same tagging convention if built in parallel)

## Files touched
- `assets/js/dom_reader.js` — edit

## Implementation spec
**Submit-button heuristic, priority order:**
1. `button[type="submit"]`, `input[type="submit"]` → score 100
2. `role="button"` combined with text content or `aria-label` containing `submit`, `apply`, `nộp`, `gửi`, `ứng tuyển` (case-insensitive) → score 90
3. Any clickable element (`<button>`, `<a>`, `role="button"`) whose visible text content matches those same keywords → score 70
- Function: `__domReader_getSubmitCandidates()` → same shape as milestone 10's search candidates, capped top 3.

**Labeled form-field heuristic (general — name/phone/email/etc.), not score-filtered:**
- Function: `__domReader_getLabeledFields()` → for every `<input>`/`<select>`/`<textarea>` not already claimed by the search heuristic (milestone 10), resolve a label via, in priority order: (1) a `<label for="...">` pointing at it, (2) `aria-label`, (3) `placeholder`, (4) `name` attribute, (5) nearest preceding text-node sibling within the same `<form>`. Returns `{elementId, tag, type, resolvedLabel, labelSource}` for **every** field found — deliberately not score-filtered/capped like search/submit, since every real form field is potentially relevant to the fill loop. `labelSource` is passed downstream so milestone 39's AI matching can weight a `label[for]` match higher than a guessed-from-sibling-text one.

## Definition of Done
- [ ] Local fixture with `<button type="submit">Ứng tuyển</button>` and 2 other clickable non-submit elements → `getSubmitCandidates()` returns exactly 1 entry
- [ ] Local fixture with 3 labeled inputs (one via `<label for>`, one via `placeholder` only, one via preceding sibling text only) → `getLabeledFields()` returns 3 entries with correct `labelSource` values for each

## Size
M
