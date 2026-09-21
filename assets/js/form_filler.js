// Injected script — locates a form field and sets its value, dispatching
// input/change events so the host page's own JS recognizes the fill.
// See spec.md §5, §6 "Form-Fill Orchestrator" (field-by-field confirm
// loop — one field at a time, not a single fill-everything pass).
//
// TODO: locate a field by label/placeholder match
// TODO: set element.value and dispatch input (and change, where needed)
// TODO: re-read the field after filling to confirm the value stuck
//       before reporting success (spec.md §3 Error Recovery)
// TODO: focusElement(nodeRef) — Feature 2 "Guided TalkBack Assist";
//       relies entirely on the WebView's own accessibility bridge to
//       TalkBack. UNCONFIRMED pending spike A1b (plan.md) — do not wire
//       this up as if it's known to work.
//
// No real fill logic yet — scaffolding pass only.
