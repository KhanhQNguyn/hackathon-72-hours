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

> "Before generating or reviewing any UI or interaction flow, check it against the checklist in 10-accessibility-wcag.md (WCAG 2.2 AA standard). If you find a violation, propose a specific fix instead of just naming the issue."

## Note for the pitch (Day 3)

Since this is an Accessibility Design Competition, proactively stating exactly where you applied WCAG 2.2 AA, with concrete examples (not just a general "we care about accessibility"), is almost certainly a key part of pitch.md. Trace every completed checklist item back to the exact Rubric line it addresses in intent.md.

## ⚠️ Cần điền khi cuộc thi bắt đầu

- [ ] Không cần điền gì thêm — file này là checklist cố định, dùng nguyên trong suốt cuộc thi.
