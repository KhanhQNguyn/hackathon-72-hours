# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a **planning-artifact chain** for an ADC Hackathon 2026 entry targeting **Stage 2 — Job Search & Application** (Technological Solutions category): a voice-driven Flutter app that helps blind/low-vision job seekers get past four accessibility barriers — job descriptions posted as images, inaccessible job portals/company websites, unreadable PDF application forms, and filling in/submitting the application itself. (The repo previously targeted a different assignment — a Shopee voice-ordering app — before the official Competition Brief was released; that framing is superseded throughout `intent/`, though `01-intent.md` preserves the old text in strikethrough as a decision trail.) There is **no application code in this repo yet** — only the sequential chain of Markdown documents that fully specify what is to be built. `05-scaffolder.md` contains instructions *for* Claude Code to scaffold a Flutter project, but that scaffolding has not been executed in this repo — check before assuming `lib/`, `android/`, `pubspec.yaml`, etc. exist.

Because of this, there are no build/lint/test commands to run here. If asked to run the project, first check whether `05-scaffolder.md` has actually been executed (look for `pubspec.yaml`); if not, that's the first step, not `flutter run`.

## The artifact chain

Each numbered file is generated from the ones before it, and every file stays editable as the plan evolves — this is not a write-once spec.

```
docs/
├── intent/
│   ├── 01-intent.md           ← Problem, Users, Outcome, Features, Constraints, Rubrics (start of chain)
│   ├── 02-spec.md             ← tech stack, architecture, domain model (schema/endpoints folded in — see below)
│   ├── 05-scaffolder.md       ← Claude Code instructions to generate the initial codebase (not yet run)
│   ├── 06-plan.md             ← execution plan, split into parallel workstreams
│   └── 10-accessibility-wcag.md  ← WCAG 2.2 AA + Universal Design checklist, applied at every step (not just at the end)
├── theme/
│   ├── 07-frontend-generation.md  ← workflow for generating UI via v0/stitch/Figma
│   ├── 08-design.md           ← UI design tokens/components derived from theme/references
│   └── 09-taste.md            ← running log of aesthetic likes/dislikes, updated continuously during build
└── _skill-format-example.md   ← reference format for turning a checklist file into a loadable Claude skill
references/                     ← screenshots of reference UI pages (for 07/08)
```

**Note on layout:** the artifact chain was moved from top-level `intent/`/`theme/` into `docs/intent/`/`docs/theme/` partway through the project (git still shows the old top-level files as deleted, uncommitted, alongside the new untracked `docs/` — that's an in-progress reorganization, not something to "fix" by reverting). Always check `docs/intent/` first; if it's missing, fall back to checking top-level `intent/`.

**`03-schema.md` and `04-endpoints.md` were deliberately skipped** (documented as a decision in `02-spec.md` §8): the product has no backend and no database, so there's nothing to model. Local state is documented directly in `02-spec.md` §8 instead of a separate schema file — as of the latest incremental update, it's a three-way split (`SharedPreferences` for simple settings, `sqflite` for the structured applicant profile, `flutter_secure_storage` for sensitive PII fields within it), not a single `SharedPreferences` store.

### Run order (not numeric file order)

`05-scaffolder.md` (code skeleton) is meant to run *before* `06-plan.md` (detailed execution plan), because the plan needs to know how the code is already organized to split work accurately: `01 → 02 → 05 → 06 → 07 → 08 → 09 (parallel, from 07 onward) → 10 (applied throughout, starting at 02, not just at the end)`.

### The governing principle

When any new idea comes up, ask: **"Does this serve a rubric line in `01-intent.md`?"** If not, it goes into that file's Open Questions section, not into the build. Scope creep is the primary risk in a 72-hour build.

## Editing conventions in this repo

- Each `docs/intent/` and `docs/theme/` file ends with a `⚠️ Cần điền khi cuộc thi bắt đầu` (fill in once the competition starts) checklist — Vietnamese, listing what's still a placeholder pending information released on Day 1 (Competition Brief, rubric weights, team name, etc.). Keep this section updated as items get resolved rather than deleting it.
- Placeholder cells use `_(để trống)_` ("leave blank") — these are intentional, not missing content to invent. Don't fabricate values for them (e.g. color tokens in `08-design.md`, page lists in `07-frontend-generation.md`) until the real upstream input exists.
- Struck-through text (`~~...~~`) in `01-intent.md` records a superseded decision along with why it was replaced — preserve this history when editing rather than deleting the strikethrough, since it documents the reasoning trail the competition may ask about.
- `10-accessibility-wcag.md` is a loadable skill/checklist, not a one-time artifact: apply it whenever touching `02-spec.md`, `08-design.md`, frontend generation, or any UI-related build/test step — see `_skill-format-example.md` for the format to convert it (or any file) into an actual Claude skill file.
- `repomix-output.xml` is a generated repo bundle (via repomix) — treat it as a build artifact, not a source file to hand-edit.

## Key architecture decisions already locked in `02-spec.md` (don't relitigate without cause)

- **No custom backend.** Flutter app calls the OpenAI API directly over HTTPS; this is a deliberate scope cut for the 72h build, not an oversight (client-side API key risk is documented and accepted, mitigated only by keeping the key out of Git).
- **Orchestration is a Finite State Machine**, not ad-hoc feature code: `Idle → Listening → ParsingIntent → LoadingTarget → ReadingContent → AwaitingUserAction → FillingForm(perFieldConfirmLoop) → FinalReview → [EditingField(fieldId) → FinalReview]* → AwaitingSubmitConfirmation → Done`, with `Error/Retrying` transitions back to the failed state. `FillingForm` confirms one field at a time before advancing; `EditingField` is a loop-back from `FinalReview`, re-confirming a single field without restarting. This is the single source of truth for flow position and makes retry logic a normal transition instead of special-cased code. Two named features now exist — **Feature 1 "AI Auto-Pilot"** (this whole loop, must-have) and **Feature 2 "Guided TalkBack Assist"** (a should-have addition reusing the same WebView/JS stack via a `focusElement(nodeRef)` call; its `.focus()`-triggers-TalkBack mechanism is unconfirmed pending its own spike, per `06-plan.md` task A1b) — see `01-intent.md` §4.
- **Web content is read via an in-app WebView (`flutter_inappwebview`) + injected JavaScript (DOM access), not Android `AccessibilityService`.** An earlier design used `AccessibilityService` to read a third-party native app's UI tree; that has a known blind spot on WebView-rendered content (confirmed via the team's own real-device testing), which matters because the confirmed target — VietnamWorks — *is* web content. `flutter_inappwebview` was chosen over `webview_flutter` specifically because the target is a real, uncontrolled third-party site: its `WebMessageListener` can restrict which origins may send messages back, and `UserScript` injection at `AT_DOCUMENT_START` supports attaching a `MutationObserver` before the page's own scripts run — feeding a perceive → act → wait-for-stable → perceive-again loop rather than a single upfront DOM read.
- **Android-first, not strictly Android-only.** The WebView/JS mechanism itself is less platform-constrained than the old `AccessibilityService` approach, but the working prototype still targets Android first for 72h tooling/time reasons — see `01-intent.md` §5.
- Full Clean Architecture (entities/use-cases/repositories/DI) was explicitly rejected in favor of a lighter layered+FSM split — right call for production, not worth the setup cost for a 3-person/72-hour build.
- **AI-screening bias (behavior-clustering by employer-side systems) is an explicit, stated exclusion**, not a gap — see `01-intent.md` §1/§4. Don't propose building around it; the document explains why that would be evasion, not a fix.
