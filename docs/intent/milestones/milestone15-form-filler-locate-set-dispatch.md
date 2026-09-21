# Milestone 15 — `form_filler.js`: locate field + set value + dispatch events

**One-line goal:** given a previously-detected field's node id, set its value in a way that actually survives framework re-renders, and dispatch the events the host page expects.

## Project context
`assets/js/form_filler.js` is the injected script that performs the actual form-filling side effect, once a field has been confirmed in the per-field loop (milestone 05). Full background: `02-spec.md` §5–§6 ("Form-Fill Orchestrator").

## Maps to plan.md task(s)
A3 (part 1 of 3)

## Preconditions
Milestones 10, 11 (reuses the `data-app-node-id` tagging convention)

## Files touched
- `assets/js/form_filler.js` — edit

## Implementation spec
- `__formFiller_setValue(nodeId, value)`: looks up the element by `data-app-node-id="${nodeId}"` (set during the most recent `readDom()` pass). If the DOM has since re-rendered and the attribute is gone, return `{"success": false, "reason": "node_stale"}` immediately rather than throwing — so the Dart layer (milestone 16) can trigger a fresh `readDom()` and retry.
- **Set the value via the native property setter, not a plain assignment** — this specific technique is required to survive React/Vue-controlled inputs, which override a plain `.value = x` on their next re-render:
  ```js
  Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')
    .set.call(element, value);
  ```
- Dispatch, in order: `new Event('input', {bubbles: true})`, then `new Event('change', {bubbles: true})`.
- Return `{"success": true}` immediately. **Verify-after-action (re-reading to confirm the value stuck) is deliberately NOT part of this milestone** — that's milestone 16, kept separate since it's a genuinely distinct concern (per `02-spec.md` §5's "Verify-after-action" bullet: a JS call returning without error is not proof the mutation actually stuck).

## Definition of Done
- [ ] Local fixture with a plain (non-framework) `<input>` → `setValue` followed by reading `element.value` directly shows the new value
- [ ] Local fixture simulating a controlled input (a small inline script that resets `.value` on every plain assignment, mimicking React) → the native-setter technique still makes the value stick, where a naive `element.value = x` would not — write this as an explicit **negative-control test case** (temporarily swap in the naive assignment and confirm the test then fails, proving the test itself is meaningful)

## Size
M
