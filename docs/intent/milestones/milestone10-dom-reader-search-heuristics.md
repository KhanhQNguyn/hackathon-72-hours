# Milestone 10 — `dom_reader.js`: search-field candidate heuristics

**One-line goal:** cheaply narrow the DOM down to a short, ranked list of search-field candidates in JavaScript, before anything is sent to the AI — the first concrete piece of this project's two-stage heuristic-filter-then-AI-rank design.

## Project context
This project's design (see `02-spec.md` §5 "Heuristic pre-filtering before AI selection") deliberately does **not** send the AI a raw DOM/HTML dump to locate elements. The injected JS first narrows candidates using cheap attribute/DOM heuristics, and only that short structured list goes to the AI (milestone 39) for final ranking — cheaper (token cost/latency) and more reliable (ranking a handful of pre-narrowed candidates beats asking the AI to locate elements cold on an unfamiliar page).

## Maps to plan.md task(s)
A2 (part 2 of 4)

## Preconditions
Milestone 09

## Files touched
- `assets/js/dom_reader.js` — edit
- `lib/models/dom_snapshot.dart` — edit (extend `DomFormField` with `role: 'search'|'submit'|'text'|'unknown'` and `heuristicScore: int`)

## Implementation spec
**Heuristic rule set, in priority order (highest-priority match wins; ties keep all matches as candidates):**
1. `input[type="search"]` → score 100
2. `[role="search"]` on the element itself or an ancestor `<form>`/`<div>` within 2 levels → score 90
3. `placeholder`, `aria-label`, or `name` attribute (case-insensitive substring match) containing any of: `search`, `tìm kiếm`, `từ khóa`, `keyword` → score 70
4. `input[type="text"]` that is the first text input inside a `<form>` whose `action`/`id`/`class` contains `search` → score 50

- Function: `__domReader_getSearchCandidates()` → JSON array of `{elementId, tag, type, role, placeholder, ariaLabel, name, heuristicScore}`, sorted descending by score, **capped at the top 5** — this cap is what makes it a "short candidate list."
- **`elementId` generation:** the real page won't have stable IDs. Inject a temporary `data-app-node-id` attribute (a UUID, or an incrementing counter scoped to this page-load session) onto every candidate element at read time, so `form_filler.js` (milestone 15) can re-locate the exact same element later in the same session.

## Definition of Done
- [ ] Local HTML fixture with 4 inputs — one `type="search"`, one `placeholder="Tìm kiếm việc làm"`, one `role="search"` div wrapper containing a plain text input, one plain unrelated text input — `getSearchCandidates()` returns exactly 3 entries (excluding the unrelated one), correctly ordered by score
- [ ] Every returned candidate has a `data-app-node-id` attribute actually present and readable in the live DOM after the call (verify with a second `evaluateJavascript` query)

## Size
M
