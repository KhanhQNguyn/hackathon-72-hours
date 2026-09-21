# Milestone 27 — `voice_trigger_button.dart` + `home_screen.dart` wiring + Semantics audit

**One-line goal:** wire the trigger button to the FSM, disable it appropriately outside `Idle`, and re-verify every icon in the app has a proper accessibility label.

## Project context
`02-spec.md` §7: every interactive widget needs a `Semantics` label — no exceptions, even on a "temporary" debug button — and this maps to WCAG 3.3.2 (Labels or Instructions) / 4.1.2 (Name, Role, Value) / 2.4.7 (Focus Visible).

## Maps to plan.md task(s)
B2 (part 2 of 2)

## Preconditions
Milestone 04, milestone 26

## Files touched
- `lib/ui/widgets/voice_trigger_button.dart` — edit
- `lib/ui/screens/home_screen.dart` — edit
- `lib/ui/screens/settings_screen.dart` — edit (Semantics audit only in this milestone — milestones 31/33 add the screen's real content)

## Implementation spec
- `voice_trigger_button.dart`'s `onPressed` calls `context.read<ApplicationFlowFsm>().transition(TriggerPressed())`.
- Button is disabled (`onPressed: null`) whenever `fsm.state is! IdleState`. Per WCAG 2.4.7/4.1.2, a disabled interactive element must still be perceivable as disabled, not just visually greyed out — confirm Flutter's `FloatingActionButton` with `onPressed: null` actually conveys `Semantics(enabled: false, ...)` to TalkBack; don't assume it does without checking.
- Icon audit: every icon currently in the app (the mic icon on the trigger button, already labeled from scaffolding) gets re-verified — this milestone's job is to catch any new icons introduced elsewhere in B2/B4/B6 work, not to redo already-correct labeling.

## Definition of Done
- [ ] Pressing the trigger button while `fsm.state is IdleState` fires `TriggerPressed`
- [ ] Pressing it (attempting to) while in any other state does nothing, and TalkBack announces the button as disabled
- [ ] A quick pass with Google's Accessibility Scanner (used properly in milestone 43, but worth a cheap early check here) reports no missing-label findings on the home screen

## Size
M
