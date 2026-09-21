# Milestone 02 — Spike: `.focus()` via JS injection → TalkBack announcement

**One-line goal:** prove that calling `.focus()` on a DOM element via the JS bridge produces a real, audible TalkBack announcement — the load-bearing, currently-unconfirmed mechanism behind Feature 2 ("Guided TalkBack Assist").

## Project context
`job_access_assist` is a Flutter/Dart Android app helping blind/low-vision job seekers search and apply for jobs by voice, via an embedded `flutter_inappwebview` WebView. Feature 2 (should-have, built only after Feature 1 works) lets the user ask the AI to move focus to an on-page element, relying entirely on the WebView's own OS-level accessibility bridge to Android's TalkBack — no separate accessibility mechanism this project builds. Full background: `01-intent.md` §4, `02-spec.md` §5.

## Maps to plan.md task(s)
A1b

## Preconditions
None — run in parallel with milestone 01, not blocking on it. These are independent questions: milestone 01 validates DOM reading in general; this one validates one specific JS-to-accessibility-tree interaction.

## Files touched
- `lib/ui/screens/spike_harness_screen.dart` — edit (reuse milestone 01's harness; add a third button)

## Implementation spec
- Add a "Focus element" button that calls `controller.evaluateJavascript(source: "document.querySelector('input').focus()")` against a detected input on the currently-loaded real page (reuse whatever page milestone 01 loaded).
- **Test with TalkBack enabled on the physical test device**, not just the emulator's default TalkBack, which can behave differently for WebView content.

## Definition of Done
- [ ] With TalkBack on, pressing "Focus element" produces an audible TalkBack announcement naming the focused input (its label/placeholder) — with no other user interaction in between
- [ ] Result (pass/fail) is written back into `01-intent.md` §7 / `02-spec.md`'s "To fill in" checklist as the resolution of the "Feature 2 mechanism unconfirmed" open item
- [ ] If FAIL: do not start any future Feature-2-specific work (Feature 1 and every milestone in this index besides Feature-2-specific ones are entirely unaffected either way, since Feature 2 is additive, not load-bearing for the MVP)

## Size
S
