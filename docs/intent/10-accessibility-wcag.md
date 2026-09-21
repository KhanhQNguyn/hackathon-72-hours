# accessibility-wcag.md — WCAG reminder skill for AI-native SDLC

**Purpose:** this isn't an artifact generated once and forgotten — it's a skill/checklist applied throughout every step from spec.md to build and test. Feed this file into Claude's context at every UI-related step (spec, design, frontend generation, build, test) to avoid generating an interface that looks good but doesn't actually work for people with disabilities — especially critical since this is an Accessibility Design Competition.

## Background knowledge (verified)

- The current standard is WCAG 2.2 (World Wide Web Consortium, published October 2023) — the latest version, adding 9 new success criteria on top of WCAG 2.1, focused on mobile accessibility, cognitive disabilities, and low vision.
- WCAG 2.2 is fully backward-compatible with 2.1 — meeting 2.2 AA automatically satisfies 2.1 AA.
- There are 3 conformance levels: A (minimum), AA (the practical standard required by most laws and competitions), AAA (highest, usually not mandatory). → Target for this project: **WCAG 2.2 Level AA**.
- 4 founding principles (POUR):
  1. **Perceivable** — information must be presentable in ways users can perceive (not dependent on a single sense)
  2. **Operable** — every function must be operable, including without a mouse or without sight
  3. **Understandable** — content and operation must be clear and predictable
  4. **Robust** — works well with assistive technologies (screen readers, etc.)

## Universal Design — 7 Principles (design-level lens, complements POUR below)

**Purpose of this section:** POUR/WCAG is a *technical compliance checklist* for digital content — it tells you whether a specific screen or component passes/fails. Universal Design is a *design-thinking lens*, applied one level up, before you get to individual components — it asks whether the overall product concept itself is inclusive by default, not retrofitted. Use this section when discussing `01-intent.md` (Problem/Solution framing) and `08-design.md` (overall UX approach), not just at the component-level checklist stage.

*(Source: from the ADC Hackathon 2026 Day 1 workshop "Designing for Everyone: A First Step into Accessibility & Universal Design")*

| # | Principle | What it means | Example |
|---|---|---|---|
| 1 | **Equitable Use** | The design is useful and fair for people with all kinds of abilities. It does not single out or stigmatize any user group. | Automatic sliding doors that work equally well for a wheelchair user, a parent with a stroller, or someone carrying boxes |
| 2 | **Flexibility in Use** | The design accommodates a wide range of individual preferences and abilities. | Scissors with handles comfortable for both left- and right-handed users |
| 3 | **Simple and Intuitive Use** | The design is easy to understand regardless of the user's experience, language skills, or current level of concentration. | Clear, universally understood icons on a microwave; a door lever instead of a confusing twist knob |
| 4 | **Perceptible Information** | The design communicates necessary information effectively through multiple senses, regardless of sensory ability or ambient conditions. | Pedestrian crossing signals with an audible click/voice prompt alongside the visual walk light |
| 5 | **Tolerance for Error** | The design minimizes hazards and adverse consequences of accidental or unintended actions. | An "Undo" button in software; high-contrast, non-slip stair edge strips |
| 6 | **Low Physical Effort** | The design can be used efficiently and comfortably, with minimal fatigue. | Touchless motion-sensor faucets; rocker light switches |
| 7 | **Size and Space for Approach and Use** | Appropriate size and space is provided for approach, reach, and use, regardless of the user's body size, posture, or mobility. | Wide hallways, adjustable-height checkout counters |

### How this maps to the current build (Stage 1 direction)

- **#1 Equitable Use** — directly informs the pitch framing: the voice-guided flow should be positioned as *one interaction model that also happens to work for sighted users* (faster, hands-free), not a segregated "special mode for disabled users." This mirrors the "secondary user" note already captured in earlier `01-intent.md` drafts — keep that framing regardless of which app/barrier is finally targeted for Stage 1.
- **#3 Simple and Intuitive Use** + **#5 Tolerance for Error** — these two directly justify the FSM's confirmation-checkpoint design (pause and confirm before an irreversible action, narrate every step) that's already built into `02-spec.md`/`06-plan.md`. When writing the pitch deck, cite these two principles by name as the design rationale — it's a stronger, more credible answer to "why does your flow pause here?" than just "we thought it was safer."
- **#4 Perceptible Information** — reinforces the existing rule that status/errors must never be TTS-audio-only (already captured as a `Semantics(liveRegion: true)` requirement in `02-spec.md` §7) — this is the Universal Design justification for that WCAG-level implementation detail.
- **#2, #6, #7** — less directly applicable to a voice-first mobile app (they're more physical/environmental), but worth a one-line acknowledgment in the deck's "we considered the full Universal Design framework, not just WCAG" narrative, since judges from the Day 1 workshop will recognize the framework by name.

## Checklist by SDLC step

### When writing spec.md / scaffolder.md

- [ ] Use semantic HTML (`<button>`, `<nav>`, `<main>`, `<label>`...) instead of `<div>` with `onClick`
- [ ] Declare `<html lang="...">` with the appropriate language
- [ ] Auth architecture includes a verification method that doesn't rely entirely on visual recognition/hard CAPTCHAs (WCAG 2.2 SC 3.3.8 – Accessible Authentication)

### When writing design.md

- [ ] Text/background contrast ≥ 4.5:1 (regular text), ≥ 3:1 (large text ≥18px or icons)
- [ ] Never convey information by color alone (e.g. form errors need an icon/text, not just a red border)
- [ ] Touch targets (buttons, links) at least 24×24px (WCAG 2.2 SC 2.5.8)
- [ ] Clear visible focus state for every interactive element (WCAG 2.2 SC 2.4.11 – Focus Not Obscured)
- [ ] Layout doesn't break when text is zoomed to 200%

### When building the frontend

- [ ] The entire flow is operable via keyboard only (Tab, Enter, Esc), no mouse required
- [ ] Images have meaningful alt text describing content/function (decorative images get `alt=""`)
- [ ] Form inputs have properly associated `<label>`s; error messages are announced to screen readers (`aria-live` or `aria-describedby`)
- [ ] Avoid requiring drag-and-drop actions without a click/tap alternative (WCAG 2.2 SC 2.5.7)
- [ ] Video/audio has captions or a transcript if applicable

### When testing (before Day 3 submission)

- [ ] Test keyboard-only — complete the entire main flow without a mouse
- [ ] Test with a screen reader (VoiceOver on Mac, NVDA on Windows, or a built-in screen reader) for at least one core flow
- [ ] Run an automated tool (e.g. axe DevTools, Lighthouse Accessibility audit) to catch basic issues — note: automated tools only catch roughly 30–40% of issues and don't replace manual testing
- [ ] Check contrast with a tool (e.g. WebAIM Contrast Checker)

## Sample prompt to load this skill into Claude

> "Before generating or reviewing any UI or interaction flow, check it against the checklist in 10-accessibility-wcag.md (WCAG 2.2 AA standard) AND against the 7 Universal Design principles above. WCAG tells you if a component is compliant; Universal Design tells you if the overall concept is inclusive by default. If you find a violation of either, propose a specific fix instead of just naming the issue."

## Note for the pitch (Day 3)

Since this is an Accessibility Design Competition, proactively stating exactly where you applied WCAG 2.2 AA, with concrete examples (not just a general "we care about accessibility"), is almost certainly a key part of pitch.md. Trace every completed checklist item back to the exact Rubric line it addresses in intent.md. **Also name the specific Universal Design principle(s)** behind key UX decisions (see mapping above) — this shows the team engaged with both frameworks taught in the Day 1 workshop, not just the compliance checklist.

## ⚠️ Cần điền khi cuộc thi bắt đầu

- [ ] Không cần điền gì thêm cho phần WCAG/POUR — đây là checklist cố định, dùng nguyên trong suốt cuộc thi.
- [ ] Phần "How this maps to the current build" cần cập nhật lại một khi đã chốt app đích/barrier cụ thể cho Stage 1 (hiện đang viết theo hướng chung, chưa gắn với 1 app cụ thể).