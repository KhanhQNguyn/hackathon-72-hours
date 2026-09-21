# Milestone 43 — TalkBack pass + Accessibility Scanner

**One-line goal:** manually verify the app's own UI is fully navigable with TalkBack, then run an automated supplementary check — before the final demo recording, not after.

## Project context
`02-spec.md` §7: *"before the demo recording, run the app's own UI with TalkBack enabled and confirm it's fully navigable — cheapest, highest-credibility accessibility validation step available, and directly demonstrates 'we practice what we preach' to judges."* Google's Accessibility Scanner catches roughly 30–40% of issues and does not replace this manual pass.

## Maps to plan.md task(s)
B6

## Preconditions
Milestones 26, 27 (ideally also 33 and 42, so the full real UI surface exists — this task is inherently iterative and can be re-run later as more UI is added)

## Files touched
Whichever UI files the pass surfaces issues in — not predictable in advance.

## Implementation spec
- With TalkBack enabled on a real device, navigate **every** screen (home, settings) using only swipe gestures — no direct tapping. Fix anything unreachable, unlabeled, or read in the wrong order.
- Run Google's Accessibility Scanner app against the built debug APK as a supplementary automated pass.

## Definition of Done
- [ ] Every interactive element on every screen is reachable via TalkBack swipe navigation alone, in a logical order
- [ ] Accessibility Scanner reports zero findings, or every remaining finding is triaged and explicitly accepted with a documented reason — not silently ignored

## Size
M
