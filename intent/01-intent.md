# intent.md — [Product Name TBD]

## 1. Problem

- What problem are we solving?
  ~~Blind/low-vision users can't quickly navigate to an app~~ — **superseded, see pivot below.** Reaching the app is not the real bottleneck: Siri (SiriKit/App Intents) and Android Voice Access already launch apps by voice. That's a solved problem and would score poorly on Innovation & Impact.

  ~~General "in-app task completion" for any workplace app~~ — **narrowed further to a concrete target.** We are building an AI layer, on top of/alongside VoiceOver, that helps a blind user complete a **product/food order on Shopee/ShopeeFood** without having to linearly swipe through every unrelated element on screen. Founder's own tested pain points using VoiceOver on Shopee to order a product:
  1. The screen is dense with elements unrelated to the ordering task (ads, recommendations, banners, navigation chrome) that VoiceOver reads through in full.
  2. Popup ads/promos dynamically interrupt and steal VoiceOver's focus mid-task, derailing the user.
  3. **VoiceOver sometimes announces the wrong content for an item** — misreading/mislabeling a food/product name, or reading a generic underlying element label (e.g. "button," "image," a stale/placeholder string) instead of the actual food/product name. This isn't a VoiceOver bug so much as a symptom of Shopee's own UI having missing or incorrect accessibility labels on its elements — meaning the accessibility-tree data itself can't always be trusted at face value.

  The AI layer takes a stated goal ("order this product," "reorder my usual"), reads the current screen (Android `AccessibilityService` tree — the same public API TalkBack/Voice Access use to inspect other apps), filters out irrelevant/promotional noise, locates the actually-relevant control even when mislabeled, **cross-checks/corrects mislabeled or missing element names (likely needs a vision-AI fallback — e.g. reading the product image/visible text when the accessibility label is wrong or generic — not accessibility-tree data alone)**, and guides/acts on it directly — skipping the swipe-through-everything default behavior and avoiding mis-ordering the wrong item.
- Why does this problem matter (who's affected, how are they currently coping)?
  Blind/low-vision users doing everyday e-commerce tasks (ordering food/products) via VoiceOver on apps like Shopee currently must swipe through every element linearly, including ads and unrelated UI, and get derailed by popups stealing focus — turning a simple purchase into a long, frustrating, error-prone task, often requiring a sighted person's help. **Workplace framing bridge (needs brief confirmation Day 1):** reframe as reclaiming work-time/independence lost to inaccessible daily-life admin (e.g. ordering lunch/office supplies) during the workday — check actual Competition Brief wording before finalizing this framing in the deck.
  _(still open — validate specifics with end-users at Day 2 fireside chat: which parts of the Shopee flow are worst, how they cope today in their own words)_

## 2. Users

- Who is this for? (Main persona)
  **Primary:** Blind or low-vision smartphone users who rely on VoiceOver/TalkBack as their primary navigation method — in the ADC context, specifically in a **workplace** setting (per ADC's overall theme: "workplace accessibility and inclusion for people with disabilities"). This stays the main persona for the hackathon — the pitch, demo, and judging framing are built around them, since that's the assigned focus area.
  **Secondary/additional (not the hackathon focus, but a natural extension):** anyone can use the same voice-ordering flow to skip Shopee's manual search → browse → checkout process — e.g. sighted users who just want faster/hands-free ordering. This isn't a second persona to design for during the hackathon (no separate UI/flow needed — the voice flow already works for a sighted user too), but it's worth one line in the deck as a market-expansion/impact point: an accessibility-first product that turns out to be useful for everyone, not an accessibility-only niche tool.
- How many user groups are there?
  **One, for build/design purposes.** Single persona: the blind/low-vision end-user placing their own order on Shopee. No secondary admin/caregiver role, and no separate build track for sighted users — the flow is self-directed and confirmed by the user in the moment (product match + payment handoff), so there's nothing for a second persona to configure or manage, and the same interaction model serves both the primary and secondary audience without extra work. (Edge case, not a separate persona: same user ordering on behalf of someone else — e.g. office lunch — uses the identical flow.)

## 3. Outcome

- What should the product achieve?
  A blind/low-vision user speaks one natural-language order command ("order Pho Bo on Shopee") and the app autonomously handles search → filter out ads/noise → product matching → cart → checkout form-fill, narrating progress at each stage — collapsing what is currently a long, error-prone, ad-derailed manual VoiceOver session into a short guided voice interaction, while keeping the user in control at the two points that matter: confirming the product match, and manually authorizing the actual payment (OTP/biometric/PIN — not automatable, and intentionally left to the user for trust/agency reasons).
- What measurable result happens after a user uses the product?
  Time-to-order and number of manual swipes/interactions drop substantially vs. default VoiceOver on Shopee; user reaches the payment-authorization screen with the correct item in cart, without having had to navigate the noisy default UI themselves. _(exact target numbers — open, to benchmark against baseline VoiceOver flow during Day 2 testing)_

## 4. Core Features

1. **Voice command intake** — natural-language order request ("order Pho Bo on Shopee") parsed into a search query/intent.
2. **AI-filtered product search & match** — reads Shopee's UI (Android `AccessibilityService` tree, real app, not a mock), suppresses ads/promo/irrelevant elements, surfaces the best product match, and **reads it aloud for user confirmation** (name, price, rating, seller) before proceeding.
3. **Autonomous cart → checkout navigation with step-by-step narration** — once confirmed, AI drives add-to-cart and checkout form-fill (address, notes) end-to-end without requiring the user to manually swipe through the screen. At **every step** the AI announces which step it's currently on (e.g. "adding to cart," "filling in delivery address," "applying voucher") so the user always knows where the process is — not just at the two confirmation checkpoints. **Key checkout details are read aloud explicitly**, especially the **delivery address**, so the user can catch and correct a wrong/outdated address before the order is placed — this was a named risk (shipping to the wrong location) if the form is filled silently.
4. **Hard stop + handoff at payment authorization** — AI presents the final order summary aloud (item, price, address, total) and **stops**, handing control back to the user for OTP/biometric/PIN — by design, not a technical shortcut, since this boundary can't be automated around and shouldn't be for trust/agency reasons.
5. _(open — 5th slot available if needed, e.g. a "read back my cart/order status" utility, or explicitly cut to keep MVP to 4 for time)_

> **Notification vs. confirmation, distinguished:** the AI **narrates every step** of the flow (informational, no action needed from the user) — but only **pauses and requires explicit user action** at two checkpoints: **product match** and **pre-payment handoff**. Continuous narration ≠ continuous confirmation; this keeps the user fully informed without slowing the flow down with unnecessary back-and-forth.

## 5. Constraints

- **Time:** Submission deadline **7:00 AM Wed 23 Sep 2026** (72h from now). Team's unique submission link arrives 1:00 PM Day 2. Competition Brief releases 9:00–10:00 AM Day 1 — Problem/Users/Outcome above are provisional until then.
- **Platform:** **Android-only** for the working prototype. Third-party apps cannot inspect/act on another app's UI on iOS (no public equivalent to `AccessibilityService`) — only Apple's own VoiceOver has that access. Android's `AccessibilityService` API (same one TalkBack/Voice Access use) is public and lets us read Shopee's UI tree and act on it. If Flutter is kept for the app shell, the accessibility-service integration itself will need a native Android platform channel (Kotlin) since Flutter has no direct wrapper for this. iOS may be shown only as a mockup/roadmap slide, not a working demo.
- **Target app/flow:** **Shopee only**, real app (no mocked/lookalike UI — confirmed, this matters for credibility with industry-partner judges), scoped to **2–3 pre-tested products/search queries** rather than general search. ShopeeFood or other flows are roadmap-only, not built.
- **Engineering approach:** lean on AI coding assistants (e.g. Claude Code) for implementation velocity on the Kotlin `AccessibilityService` + Flutter platform channel + AI matching/filtering logic. Note: the real bottleneck is empirical iteration against the live third-party app (device testing, ad-timing races, UI quirks per product), not code-writing speed — so coding speed buys **reliability/robustness on the 2–3 supported paths**, not broader scope.
- **Budget:** $0 (hackathon default) unless noted otherwise
- **Deliverables:** 1 slide deck (.pptx, official template, slides 1–6 fixed sequence, appendix from slide 7) + 1 video (<5 min, MP4/MOV, 16:9 landscape, slides visible) — both via team's unique submission link before 7:00 AM Day 3. No late submissions accepted.
- **Solution category:** likely **Technological Solutions** (AI & Automation for Workplace Accessibility) — to confirm on Slide 1 of deck.
- **Must have:** Video demo, slide deck, 1 fully working MVP product mobile app, 1 AI agent to execute the flow.
- **Should have:** Supporting multiple languages, mainly focused on English and Vietnamese.
- **Must NOT have:** Must not build complex UI design, since visual polish is not necessary for blind users — but the UX itself (voice flow, narration) should stay friendly for all kinds of people, not only blind/disabled users.

## 6. Success Criteria

- How do we know the MVP works?
  1. **The recorded demo video runs cleanly end-to-end** — search → AI-filtered product match (confirmed) → autonomous cart/checkout navigation with step-by-step narration → hard stop at payment handoff. This is a **pre-recorded video submission**, not a live demo during the Evaluation Round — so "no mistakes" means the *final edited take* is clean, achieved via multiple recording attempts if needed, not a single flawless live run.
  **Built-in robustness (not just retakes), because a live Finale pitch is a real possibility:** the flow itself should handle the unexpected gracefully from the start — narrating and retrying/recovering from an unexpected popup, slow-loading screen, or mismatched element ("that didn't load as expected, retrying...") rather than silently breaking. This is a build principle applied now, while writing the core flow — not a separate task. It pays off twice: fewer wasted takes for the video now, and genuine live-demo resilience later if the team reaches the top 8 (Day 3 afternoon) — at which point actual pitch rehearsal becomes relevant, but that's a later, separate task once/if it's known to be needed, not before.
  2. **App is a working, installable Android APK** (sideload, not Play Store — Play Store review timelines don't fit 72h), runnable on any Android device for the demo recording and for Day 3 evaluators to try hands-on if they choose to.
  3. **Real Shopee integration, scoped to 2–3 pre-tested products/search queries** (not fully general search) — each of the 2–3 must reliably complete the full flow through repeated testing before recording. This preserves credibility (real app, real `AccessibilityService` reads, not a mocked lookalike UI) while keeping scope achievable in ~65 remaining build hours across 3 people. General/arbitrary product search is explicitly **roadmap**, stated as such in the deck, not claimed as working today.
  4. **Deck + video together make the before/after contrast concrete** — paired with the measurable outcomes in Section 3 (time-to-order, swipe-count reduction vs. baseline VoiceOver on Shopee), so impact is shown with a number, not just asserted.
- A list of specific behaviors/scenarios that must run for it to count as "done":
  - [ ] App installs and launches on a clean Android device via APK
  - [ ] Accessibility service permission flow works (user grants it once, app functions afterward)
  - [ ] For each of the 2–3 supported products: voice command → correct product surfaced and read aloud → user confirms → cart/checkout auto-filled with narration at every step → address read aloud → flow stops cleanly at payment handoff with full order summary spoken
  - [ ] Ad popups mid-flow are detected/handled without derailing the flow (this is the core differentiator vs. raw VoiceOver — must be shown working, not just claimed)
  - [ ] At least one take of each of the 2–3 flows recorded cleanly for the video

## 7. Open Questions

- Is this an efficiency problem (faster than VoiceOver default) or also solving a deeper barrier (independence, cognitive load, anxiety about getting lost in the phone)?
- How do blind users cope with this today, in their own words? (validate with end-users on Day 2 fireside chat, 9:00–10:00 AM)
- How does this connect to ADC's overall **workplace accessibility/employability** framing — is the "app" a workplace tool navigation problem specifically (e.g. jumping between Slack/email/timesheet apps at work), or general phone use?
- What does the Competition Brief (released Day 1) actually specify as the required problem scope? All of the above is provisional until then.

**Resolved:** No approval/API access needed from Shopee — the build uses Android `AccessibilityService` (same on-device, screen-reading mechanism TalkBack/Voice Access use), not Shopee's backend or Open Platform/Affiliate API (which *would* require a days-long partner approval, but isn't what's being used here). Can build/test immediately. Minor note: Shopee's ToS likely has general "no automated access" language aimed at scraping/abuse, not accessibility tools — not a legal guarantee, but functionally this sits in the same category as any screen reader, not a scraping bot.

## 8. Rubrics (judging criteria)

**⏸ SKIPPED for now** — organiser hasn't published rubric weights or a detailed criteria breakdown yet. Revisit once the Competition Brief (Day 1, 9:00–10:00 AM) or https://apps.rmit.edu.vn/r/ADC2026 has the detail; mapping features to criteria at that point should be quick since the features are already locked.

*(criteria names below are from the ADC Hackathon 2026 Online Briefing — official weights not published)*

| Criterion | Weight | Which feature/part of the product addresses it |
|---|---|---|
| Innovation & Impact | _(open)_ | _(open)_ |
| User-Centred Design & Accessibility | _(open)_ | _(open)_ |
| Feasibility & Practicality | _(open)_ | _(open)_ |
| Utilization of AI | _(open)_ | _(open)_ |
| Presentation & Communication *(Grand Finale only, top-8 teams)* | _(open)_ | _(open)_ |

## 9. Accessibility Intent (specific to ADC)

- Focus area: **Visual Impairment** (assigned by Organising Committee — cannot be changed)
- Current access barriers this group faces with similar solutions on the market:
  _(open — quick scan needed of what VoiceOver/TalkBack shortcuts, "Voice Access"-style launchers, and AI assistants already do, so we know what NOT to rebuild and where the real gap is)_

---

## Competition Reference (from Online Briefing, confirmed)

- **Team:** 3 members, all Software Engineering majors
- **Submission type:** Technical product — mobile app (Flutter)
- **Timeline:** Day 1 (21 Sep, Learn & Frame) → Day 2 (22 Sep, Test & Refine, fireside chat + mentoring + mock pitch) → Day 3 (23 Sep, 7:00 AM submission deadline, then Evaluation Round; top 8 pitch live 2:00–4:00 PM)
- **Prizes:** 1st place = 15M VND voucher + 9M VND cash + resort vouchers + P&G Dream Internship fast-track + Katalon interview fast-track (full breakdown in briefing doc)
- **Deck template:** Slide 1 Title (project/team/focus area/solution category) · Slide 2 Instructions (non-graded) · Slide 3 Problem statement · Slide 4 Solution overview · Slide 5–6 Prototype · Slide 7+ Appendix
- **Video:** <5 min, MP4/MOV, 16:9 landscape, slide visible throughout

## ⚠️ To fill in once the competition starts

- [ ] Competition Brief content (releases 9:00–10:00 AM Day 1) — Problem/Users/Outcome depend on this
- [x] Disability Focus Area: **Visual Impairment**
- [ ] Solution Category (likely Technological — confirm)
- [ ] Team name, project name
- [ ] Rubric weights/breakdown (Section 8) — fill in once published
