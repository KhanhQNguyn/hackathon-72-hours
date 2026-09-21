# Milestone 26 — `status_narration_view.dart` real wiring

**One-line goal:** bind the on-screen status text to the FSM's current state, so a sighted teammate or judge can follow along by reading, not just by listening.

## Project context
`02-spec.md` §7 (WCAG 3.3.1 Error Identification, live-region cross-check): the visible text mirror of everything being spoken must never be audio-only, and must be a `Semantics(liveRegion: true)` region so TalkBack announces status changes even if TTS fails or is muted. `status_narration_view.dart` already has this `Semantics` wrapper from scaffolding — this milestone wires it to real state, not fake/static text.

## Maps to plan.md task(s)
B2 (part 1 of 2)

## Preconditions
Milestone 04 (FSM must exist to bind to)

## Files touched
- `lib/ui/screens/home_screen.dart` — edit
- `lib/ui/widgets/status_narration_view.dart` — edit (minor — mostly already correct from scaffolding)
- `lib/core/narration_lookup.dart` — **create fresh** (placeholder strings for now; milestone 42 supplies the real wording)

## Implementation spec
- `home_screen.dart` wraps `StatusNarrationView` in a `Consumer<ApplicationFlowFsm>`, passing `text: narrationFor(fsm.state)`.
- `narrationFor(ApplicationFlowState state)`: a thin pure function in the new `narration_lookup.dart`, mapping each `ApplicationFlowState` subtype to a display string. This milestone can ship with placeholder strings (e.g. `"Listening for your command..."`) — the **actual** finalized wording (EN + VI) is milestone 42's job; this file's job is only the plumbing.

## Definition of Done
- [ ] Changing `fsm.state` (e.g. via a temporary debug button, or by driving it in a widget test) visibly updates the on-screen text within one frame
- [ ] The `Semantics(liveRegion: true)` wrapper (already present from scaffolding) is confirmed still in place after this edit

## Size
S
