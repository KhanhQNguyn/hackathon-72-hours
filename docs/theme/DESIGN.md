# Job Access Assist — UI layout plan

## Design read

Job Access Assist is an Android accessibility companion for blind and low-vision job seekers. It should feel quiet, tactile, direct, and trustworthy: a focused assistive tool, not a generic AI product or a copy of the supplied screenshots.

`THEME.md` remains the source of truth for tokens. The reference screenshots inform only visual language: deep tonal surfaces, high-contrast state cues, generous touch areas, clear progress, and compact structural borders. Do not copy their composition, wording, navigation, or features.

Set the design controls to **variance 3/10, motion 2/10, density 4/10**. Accessibility and predictable task flow override the more decorative or motion-heavy direction in the consulted skills.

## Existing product scope

Design only for the capabilities present in the codebase:

- Voice-triggered application flow and spoken/live status.
- Listening, intent parsing, page loading, reading, listing confirmation, per-field form completion, final review, CAPTCHA, retry/error, and completion states.
- An embedded WebView for real runs.
- Settings for English/Vietnamese, applicant name, phone, email, and a CV file.
- An unsupported-platform message.

Do not add a jobs feed, saved applications, bottom navigation, analytics, an account hub, chat, or other unimplemented destinations.

## Visual system

### Frame and rhythm

Use one scrollable column inside Android safe areas. Use a 16 dp phone gutter, 24 dp on larger devices, 8–16 dp internal gaps, and 24–32 dp between groups. Visual order and TalkBack traversal order must match.

Use tonal elevation rather than shadows: `surface-base` for the page, `surface-raised` or `surface-container` for a meaningful information group, `outline-variant` at rest, `outline` when selected, and the yellow `focus-outline` with native focus semantics.

Retain the shape rule in `THEME.md`: 8 dp controls, 16 dp information groups, and 24 dp primary voice-action surfaces. Pills are limited to compact statuses and language selection.

### Type and status

Inter is the intentional product typeface because it is legible and supports Vietnamese; it overrides generic skill guidance to avoid Inter. Follow the theme scale, preserve generous line-height for diacritics, and let all containers grow at 200% Android font scaling.

| State | Token | Required visible wording |
| --- | --- | --- |
| Ready | inactive structural slate | “Ready for a voice command” |
| Listening | `state-listening` green | “Listening” |
| Working | `state-processing` blue | the real current task, such as “Reading the job page” |
| Waiting for confirmation | raised neutral surface | a direct question and explicit choices |
| Complete | green confirmation treatment | “Completed” only after `DoneState` |
| Error | error token/container | what failed and how to retry |

Each state also has an icon and semantic announcement. Color alone never communicates meaning.

## Screen plans

### Home screen

This remains the app’s principal surface, matching the existing `HomeScreen`, `StatusNarrationView`, and `VoiceTriggerButton`.

```text
Safe area
  App identity                                      [Settings]
  ─────────────────────────────────────────────────────────────
  [state icon] Ready / Listening / Working / Needs attention
  Live status and narration text

  Primary workspace
    Contextual state icon or restrained illustration
    Current task title
    Supporting narration mirror

  Primary voice action
    [ Start voice command ]
    or [ Listening… ] / disabled “Working” presentation

  Optional real-run workspace
    Embedded job-page WebView
```

The voice action is the visual anchor in idle state: a 72 dp minimum-height rounded action surface with a microphone icon and full text label. It must not remain an unlabeled floating button. The narration mirror appears above it and remains the existing live region.

In listening state, pair green with a microphone/hearing icon and the word “Listening”. A short pulse or waveform may support the state, but becomes static with reduced motion and never represents microphone activity by itself.

In parsing, loading, reading, and retrying states, pair blue with concise task-specific status. A compact progress list may show only real FSM work, such as “Understanding request”, “Opening job page”, and “Reading content”. It must never claim a result before the flow has it.

For CAPTCHA, field confirmation, final review, errors, and done states, retain the same shell and replace the workspace with current narration and the next available action. No new navigation structure is needed.

When `showWebView` is true, place the embedded page below the status and action region inside remaining vertical space. Controls must remain reachable through scrolling and must not be visually swallowed by the WebView.

### Confirmation and review

The controller already runs confirmation by voice. The workspace mirrors that flow without inventing a separate form product.

```text
[ Step label: Confirming field 2 of 5 ]
Field label
Proposed value

[ Confirm this value ]
[ Edit this value ]
```

At final review, list only values held by the existing flow in an open divided list rather than nested cards. Submit must be visually distinct from editing. Do not display or read back sensitive values. The completion presentation appears only after the real flow reaches `DoneState`; a JavaScript click is not sufficient visual evidence of success.

### Settings

Keep the existing destination and fields: language, full name, phone, email, CV selector, and save action.

```text
Safe-area app bar: Back + Settings
  Language
    English option
    Vietnamese option
  ─────────────────────────
  Applicant profile
    Full name field
    Phone field
    Email field
    [ Choose CV file ]
    selected filename or “No CV selected”
    [ Save profile ]
```

Language options are full-width selection rows with selected state expressed through text, check icon, and semantics. Inputs remain at least 56 dp high with persistent labels and adjacent validation text. The CV picker is a full-width labeled action. Snackbars remain supplementary feedback.

### Unsupported platform

Use the same dark base, one concise centered explanation, and a platform icon. It needs no decoration, secondary CTA, or product navigation. Its current semantic announcement remains primary behavior.

## Motion, haptics, and sound

- Use 150–200 ms opacity or tonal transitions. Do not move controls after users learn their position.
- Listening feedback may pulse and processing may sweep, but both stop or become static under reduced motion.
- Haptics and TTS support the visible state; they do not convey independent required information.
- Do not introduce scroll-triggered, parallax, marquee, carousel, or GSAP-style motion in this Android assistive workflow.

## Later implementation acceptance criteria

1. Every status has text, icon, semantic announcement, and non-color meaning.
2. Every interactive control meets the 48 × 48 dp minimum; the voice action is at least 72 dp high.
3. Font scaling to 200% causes vertical reflow and scrolling, never clipping or horizontal truncation.
4. Home, confirmation, review, error, and completion visuals derive from existing FSM/controller state instead of duplicated UI state.
5. The screen remains useful when TTS, motion, or haptics are unavailable.
