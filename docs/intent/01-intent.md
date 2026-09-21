# intent.md — [Product Name TBD]

## 1. Problem

- What problem are we solving?
  ~~Blind/low-vision users can't quickly navigate to an app~~ — **superseded.** Reaching the app is not the real bottleneck; this framing predates the Competition Brief.

  ~~AI layer on top of VoiceOver to complete a product/food order on Shopee/ShopeeFood~~ — **superseded by the official Competition Brief (released Day 1).** The Brief assigns barriers by employment-journey stage, not by arbitrary app choice. After analysis, the team has locked **Stage 2 — Job Search & Application**, **Technological Solutions** category.

  **Official problem statement (quoted directly from the Brief):** "Visually impaired individuals struggle to navigate and submit job applications due to inaccessible digital platforms, biases in AI screening, and a general lack of accessibility expertise and consistent testing within organisations."

  Concretely, the barriers this project targets:
  1. **Company websites and job portals are not fully screen-reader accessible** — inconsistent semantic markup, poor focus management, content that doesn't expose cleanly to assistive technology.
  2. **PDF application forms are not screen-reader friendly** (Word or an accessible/tagged PDF is preferred by the Brief, but real-world employer forms frequently aren't either).
  3. **Third-party job platforms (e.g. VietnamWorks) sometimes convert job descriptions into images**, rendering the text itself inaccessible to a screen reader — this is called out explicitly in the Brief as a known, common pattern, not a hypothetical edge case.
  4. **Employer-uploaded images instead of typed text** (common on LinkedIn and other boards) create the same barrier at the point of the job posting itself.

  **Explicitly out of scope, stated as a known limitation rather than something we attempt to fix:** the Brief also names AI screening-tool bias — systems that cluster/flag candidates by browsing behavior (dwell time, click patterns), inadvertently flagging visually impaired users even without any disclosure of disability. This is a **third-party algorithmic bias problem**, sitting inside employer-side/vendor-side screening systems this project has no visibility into or control over. Attempting to "solve" it by having the app simulate "normal" sighted-user browsing patterns to evade detection would be **evasion, not a fix — and an ethically wrong direction** (it's a form of deception about the user, not an accessibility improvement). This project does not attempt it, and says so plainly in the deck as a stated boundary of the solution.

  **Stage 1 (Career Preparation) note:** Stage 1's barriers (inaccessible job ads, portals, CV builders) are effectively a subset of Stage 2's barriers above — building for Stage 2 covers both without being built as two separate things.

- Why does this problem matter (who's affected, how are they currently coping)?
  Blind/low-vision job seekers currently depend on a sighted friend, family member, or colleague to describe image-based job postings, to navigate a poorly-labeled company careers page, or to read and fill in a PDF application form on their behalf — turning something as ordinary as applying for a job into a task they cannot fully do independently. This directly undermines ADC's workplace-accessibility/employability framing: the barrier isn't *doing* the job once hired, it's *getting past the application step* in the first place.
  _(still open — validate specifics with end-users at Day 2 fireside chat: which of these four barriers is actually worst/most common in their own experience)_

## 2. Users

- Who is this for? (Main persona)
  **Primary:** Blind or low-vision job seekers who rely on VoiceOver/TalkBack as their primary means of interacting with a phone, and who are actively searching for and applying to jobs. This stays the single persona for build/design purposes — the pitch, demo, and judging framing are built around them, since Visual Impairment is the assigned focus area.
- How many user groups are there?
  **One, for build/design purposes.** Single persona: the blind/low-vision job seeker completing their own application. No recruiter/employer-facing role and no separate build track — same reasoning as the original plan: nothing here needs a second persona to configure or manage anything, so one interaction model serves the whole scope.

## 3. Outcome

- What should the product achieve?
  A blind/low-vision user can, inside one app: hear a job description read aloud regardless of whether the source posted it as plain text or as an image; understand the full content of a company's job portal or careers page despite that page's own poor accessibility; hear a PDF application form read back in a structured, navigable way; and complete and submit that application — all without needing a sighted colleague's help at any of these four points.
- What measurable result happens after a user uses the product?
  Time-to-complete-application and number of failed/abandoned application attempts drop substantially vs. today's baseline (a sighted-helper-dependent or manual-VoiceOver-only attempt). _(exact target numbers — open, to benchmark during Day 2 testing against a real job portal/PDF)_

## 4. Core Features

### Feature 1 — "AI Auto-Pilot" (must have — build first, fully)

The end-to-end, voice-driven flow: search → read listing → fill form → submit. This is the primary MVP deliverable; every part below must be fully working, not partial.

1. **AI image-to-speech for job descriptions posted as images** — detects when a job description has been posted as an image rather than text (the Brief's own named pattern on platforms like VietnamWorks, and on LinkedIn/employer uploads), extracts the image, runs it through a vision model, and reads the actual job description content aloud. Directly addresses barriers #3 and #4 above.
2. **AI-filtered navigation/reading of inaccessible company websites and job portals** — reads the DOM of the portal/careers page the user is currently on, filters out navigation chrome/ads/irrelevant content, and surfaces and narrates the actual job-listing content (title, requirements, how to apply) in a logical order, even when the page's own semantic markup is poor. Directly addresses barrier #1.
3. **PDF application form → structured, screen-reader-friendly text/speech** — parses a PDF application form's actual text/field structure and reads it back in a navigable, spoken form, rather than leaving the user to fight an untagged PDF with a generic reader. Directly addresses barrier #2.
4. **Autonomous form-fill assistant, field-by-field, with a confirm-before-submit checkpoint** — **redesigned from a single end-of-flow readback to a field-by-field confirm loop:** for each detected form field, the AI announces the field, offers a saved applicant-profile value if one exists ("use this value, or provide a new one?") or asks the user to provide one if not, gets the user's confirmation, *then* moves to the next field — making the flow self-correcting per field rather than relying on catching every mistake in one final readback. Once all fields are confirmed, the flow enters a lightweight **Final Review** summary (not a full re-read of every field from scratch, since each was already confirmed individually) — from which the user can say **"edit [field]"** at any point before submitting to re-collect and re-confirm just that one field, looping back to Final Review afterward rather than restarting the whole form. Submitting a job application is a consequential, hard-to-undo action, so the app never submits silently or automatically — only after explicit final confirmation (checkpoint #2 below).

### Feature 2 — "Guided TalkBack Assist" (should have — build only after Feature 1's core loop works end-to-end against a real target, and only if time remains)

A narrower, distinct feature, new on top of the original pivot: within the **same** embedded WebView session Feature 1 already uses, the user can ask the AI to locate an element on the current page (e.g. *"đưa tôi tới thanh tìm kiếm"* — "take me to the search bar"), and the AI calls `element.focus()` on it via the same JS-injection bridge Feature 1 relies on. The user's own already-running TalkBack then announces that element **natively** — because WebView content is exposed through Android's accessibility tree via the standard OS-level WebView-to-Chromium accessibility bridge, not through any separate mechanism this project builds. No swipe-counting, no separate `AccessibilityService`, no new architecture: this reuses Feature 1's WebView+JS stack 100%.

**Feasibility caveat, stated plainly:** whether `.focus()` triggered via JS injection actually produces a real TalkBack announcement has **not yet been confirmed on a real device** — it needs its own small spike (see plan.md, task A1b), separate from Feature 1's DOM-reading spike (A1). If it fails, Feature 2 as designed doesn't work and needs rethinking — but Feature 1 is entirely unaffected either way, since Feature 2 is additive, not load-bearing for the MVP.

### Three checkpoints (hard stops, across both features)

1. **Selecting a company/listing** — the AI surfaces a match and the user confirms it's the right one before the flow proceeds.
2. **Confirming before final submit** — now backed by Feature 1's field-by-field confirm loop, so this is a lighter final confirmation (the Final Review summary), not a full first-time readback of untouched data.
3. **Encountering a CAPTCHA** — first try the CAPTCHA's own accessible audio-challenge option if the page offers one (many providers, including reCAPTCHA, ship this specifically for screen-reader users — using it is using an intended accessible path, not circumventing security). If no audio option exists, the flow stops and hands control to the user explicitly ("Có CAPTCHA ở đây, bạn giải giúp tôi rồi nói 'tiếp tục' nhé" — "There's a CAPTCHA here, please solve it and say 'continue'"), waiting for the user's resume command before proceeding. Same "hand back to the user at every human-verification step" principle as checkpoint #2, applied consistently — not a one-off exception.

> **Excluded from scope, stated explicitly (not a feature, not partially built):** AI screening-tool bias (behavior-clustering systems on the employer/vendor side) is not addressed by this product. See Section 1 for why — it's a third-party algorithmic problem outside a candidate-side app's technical reach, and attempting to evade it would be dishonest rather than helpful. This boundary is stated plainly in the deck, not glossed over.

## 5. Constraints

- **Time:** Submission deadline **7:00 AM Wed 23 Sep 2026** (72h from now). Team's unique submission link arrives 1:00 PM Day 2. Competition Brief released 9:00–10:00 AM Day 1 — this document reflects that Brief.
- **Platform:** The core mechanism (in-app WebView + JavaScript DOM access, see spec.md §5) is inherently less platform-constrained than the old Android-`AccessibilityService`-only approach, since it doesn't depend on an OS-level accessibility API. That said, **the working prototype still targets Android first** for the same 72h reasons as before: existing team Android/Flutter tooling, no time to also validate an iOS build in this window. iOS may be shown only as a mockup/roadmap slide, not a working demo.
- **Target app/flow:** Real job portals and PDF application forms — not Shopee. **Target platform confirmed: VietnamWorks** (previously an open "1–2 platforms TBD" question — now decided). The specific job listing and PDF application-form sample to test against (ideally one linked from/associated with the chosen VietnamWorks listing) are still to be picked by the team (see Open Questions) — the platform itself is locked. General/arbitrary portal support beyond VietnamWorks is roadmap-only, not built.
- **Engineering approach:** lean on AI coding assistants (e.g. Claude Code) for implementation velocity on the WebView/JS-bridge integration, PDF parsing, and AI matching/filtering logic. As before, the real bottleneck is empirical iteration against real third-party pages/PDFs (DOM quirks per site, PDF structure variance), not code-writing speed.
- **Budget:** $0 (hackathon default) unless noted otherwise.
- **Deliverables:** 1 slide deck (.pptx, official template, slides 1–6 fixed sequence, appendix from slide 7) + 1 video (<5 min, MP4/MOV, 16:9 landscape, slides visible) — both via team's unique submission link before 7:00 AM Day 3. No late submissions accepted.
- **Solution category:** **Technological Solutions** (confirmed, per Brief — AI & Automation for Workplace Accessibility).
- **Must have:** Video demo, slide deck, 1 fully working MVP mobile app, 1 AI agent to execute the flow.
- **Should have:** Supporting multiple languages, mainly focused on English and Vietnamese.
- **Must NOT have:** Must not build complex UI design, since visual polish is not necessary for blind users — but the UX itself (voice flow, narration) should stay friendly for all kinds of people, not only blind/disabled users.

## 6. Success Criteria

- How do we know the MVP works?
  1. **The recorded demo video runs cleanly end-to-end, covering Feature 1's full loop against the real target listing:** an image-based job description is read aloud, the portal/careers page is navigated and its listing content narrated, the PDF application form is read aloud, and the application is filled in field-by-field (each field confirmed as it's filled) and submitted only after Final Review confirmation — with a clean handling of a CAPTCHA checkpoint if one appears. This is a **pre-recorded video submission**, not a live demo during the Evaluation Round — so "no mistakes" means the final edited take is clean, achieved via multiple recording attempts if needed.
  **Built-in robustness (not just retakes):** the flow should narrate and retry/recover from an unexpected page-load failure, PDF parse failure, or missing form field ("that didn't load as expected, retrying...") rather than silently breaking — same build principle as before, in case the team reaches the Grand Finale (top 8, Day 3 afternoon) and needs genuine live-demo resilience.
  2. **App is a working, installable Android APK** (sideload, not Play Store), runnable on any Android device for the demo recording and for Day 3 evaluators to try hands-on if they choose to.
  3. **Real portal/PDF integration against the confirmed VietnamWorks target** (not fully general support) — the chosen listing/PDF sample must reliably complete its part of the flow through repeated testing before recording. General/arbitrary portal or PDF support is explicitly **roadmap**, stated as such in the deck.
  4. **Deck + video together make the before/after contrast concrete** — paired with the measurable outcomes in Section 3 (time-to-complete-application, abandoned-attempt reduction vs. baseline), so impact is shown with a number, not just asserted.
- A list of specific behaviors/scenarios that must run for it to count as "done":
  - [ ] App installs and launches on a clean Android device via APK
  - [ ] For the chosen real job listing: an image-based job description is detected and read aloud correctly
  - [ ] The chosen portal/careers page is navigated with irrelevant content filtered out, and the actual listing content is narrated
  - [ ] The chosen PDF application form is parsed and read back in a structured, navigable way
  - [ ] The application form is filled in **field-by-field**, each field confirmed (saved-profile value accepted or a new value provided) before the next is attempted, reaching a Final Review summary that the user can request an edit against before submitting
  - [ ] If a CAPTCHA is encountered: its audio-challenge option is tried first if offered, otherwise the flow narrates and hands control to the user, resuming only on an explicit "continue" command
  - [ ] Submission only happens after explicit final confirmation at Final Review
  - [ ] At least one take of the full flow recorded cleanly for the video, against the real VietnamWorks target

## 7. Open Questions

- Which specific VietnamWorks job listing to test against — needs a pick known to have an image-based job description (per the Brief's own observation that this is common on VietnamWorks and LinkedIn). The platform itself is now locked (see Constraints); only the specific listing remains open.
- A real PDF application form sample to test against — needs sourcing (ideally one linked from/associated with the chosen VietnamWorks listing) before Workstream A's spike can run.
- **Does the "AI moves TalkBack focus to an element on request" mechanism (Feature 2) actually match how blind/low-vision users would want navigation help?** This was designed by team members without lived experience of screen-reader navigation patterns — it needs real validation with end-users at the Day 2 fireside chat, not assumption. Feature 2 shouldn't be treated as correct-by-design just because it's technically feasible (and its technical feasibility itself is still unconfirmed — see Feature 2's spike caveat in Section 4).
- Is this primarily an efficiency/independence problem, or does it also touch a deeper barrier (confidence applying at all, fear of a botched application) worth naming in the pitch?
- How do blind job seekers cope with these four barriers today, in their own words? (validate with end-users on Day 2 fireside chat, 9:00–10:00 AM)

**Resolved:** No approval/API access needed from any specific job portal or platform — the app reads content it itself renders in its own embedded WebView (first-party DOM access to a page the app loaded), and parses PDF files directly; this doesn't require partner approval from VietnamWorks, LinkedIn, or any employer site. Can build/test immediately against real, public pages.

## 8. Rubrics (judging criteria)

**⏸ SKIPPED for now** — organiser hasn't published rubric weights or a detailed criteria breakdown yet. Revisit once published; check before assuming this is still blank, since the Brief itself has now been released and weights may follow. Mapping features to criteria at that point should be quick since the features are already locked.

*(criteria names below are from the ADC Hackathon 2026 Online Briefing — official weights not published)*

| Criterion | Weight | Which feature/part of the product addresses it |
|---|---|---|
| Innovation & Impact | _(open)_ | _(open)_ |
| User-Centred Design & Accessibility | _(open)_ | _(open)_ |
| Feasibility & Practicality | _(open)_ | _(open)_ |
| Utilization of AI | _(open)_ | _(open)_ |
| Presentation & Communication *(Grand Finale only, top-8 teams)* | _(open)_ | _(open)_ |

## 9. Accessibility Intent (specific to ADC)

- Focus area: **Visual Impairment** (assigned by Organising Committee — cannot be changed; unchanged from before)
- Current access barriers this group faces with similar solutions on the market:
  _(open — quick scan needed of what existing screen-reader tooling, job-portal accessibility overlays, and AI resume/application assistants already do, so we know what NOT to rebuild and where the real gap is)_

---

## Competition Reference (from Online Briefing + Competition Brief, confirmed)

- **Team:** 3 members, all Software Engineering majors
- **Submission type:** Technical product — mobile app (Flutter)
- **Assigned scope (from Competition Brief, released Day 1):** Stage 2 — Job Search & Application; Technological Solutions category
- **Timeline:** Day 1 (21 Sep, Learn & Frame) → Day 2 (22 Sep, Test & Refine, fireside chat + mentoring + mock pitch) → Day 3 (23 Sep, 7:00 AM submission deadline, then Evaluation Round; top 8 pitch live 2:00–4:00 PM)
- **Prizes:** 1st place = 15M VND voucher + 9M VND cash + resort vouchers + P&G Dream Internship fast-track + Katalon interview fast-track (full breakdown in briefing doc)
- **Deck template:** Slide 1 Title (project/team/focus area/solution category) · Slide 2 Instructions (non-graded) · Slide 3 Problem statement · Slide 4 Solution overview · Slide 5–6 Prototype · Slide 7+ Appendix
- **Video:** <5 min, MP4/MOV, 16:9 landscape, slide visible throughout

## ⚠️ To fill in once the competition starts

- [x] Competition Brief content — **released, incorporated above** (Stage 2 — Job Search & Application, Technological Solutions)
- [x] Disability Focus Area: **Visual Impairment**
- [x] Solution Category: **Technological Solutions** (confirmed)
- [ ] Team name, project name
- [ ] Rubric weights/breakdown (Section 8) — fill in once published
- [x] Target platform: **VietnamWorks** (confirmed)
- [ ] Specific VietnamWorks job listing and PDF application-form sample to test against (Section 7)
- [ ] **Audit 2026-09-22 findings** (see `audit-2026-09-22.md`): (a) spike A1b result still not recorded — needs an Android device; (b) the flow does not yet navigate from the listing page to the application form or run a search step — the largest remaining gap for the demo; (c) whether a scripted `input.click()` opens the file chooser on the real WebView is unverified — the live CV upload may need a TalkBack-activation fallback
