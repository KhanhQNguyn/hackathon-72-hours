# Milestone 13 — CAPTCHA detection heuristic

**One-line goal:** detect when a CAPTCHA is present on the loaded page, as part of every DOM perception pass.

## Project context
Checkpoint 3 of `job_access_assist`'s three hard-stop checkpoints: encountering a CAPTCHA. First try its own accessible audio-challenge option (milestone 14); if none exists, hand control to the user. This milestone is only the detection step. Full background: `01-intent.md` §4, `02-spec.md` §6.

## Maps to plan.md task(s)
B1b (part 1 of 2)

## Preconditions
Milestone 12 (reuses the perception-pass cadence and JS injection pattern)

## Files touched
- `assets/js/dom_reader.js` — edit (new function, runs as part of every perception pass)

## Implementation spec
`__domReader_detectCaptcha()`, checked in priority order, stop at first match:
1. `iframe[src*="recaptcha" i]` or `iframe[src*="hcaptcha" i]` present and visible → `{"detected": true, "provider": "recaptcha"|"hcaptcha"}`
2. Any element with `class` or `id` containing `captcha` (case-insensitive) that is visible → `{"detected": true, "provider": "unknown"}`
3. Otherwise → `{"detected": false}`

Called as part of every `readDom()` pass (milestone 12) — not a separate polling loop; reuses the same perceive-act-wait-perceive cadence already established.

**Design note:** this heuristic is deliberately permissive/false-positive-tolerant. A false "CAPTCHA detected" just triggers an unnecessary confirmation step (mildly annoying); a false negative silently blocks the flow with no explanation (much worse). This asymmetric-cost reasoning matches how other heuristics in this project are already tuned.

## Definition of Done
- [ ] A local fixture embedding a real (test-mode) reCAPTCHA widget → `detectCaptcha()` returns `{detected: true, provider: "recaptcha"}`
- [ ] A fixture with a `<div class="my-captcha-wrapper">` (no real widget inside) also returns `detected: true` — confirms the permissive design is actually implemented as intended, not accidentally over-strict

## Size
S
