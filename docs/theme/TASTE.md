# Job Access Assist — taste memory

This is the persistent UI preference for this repository. It keeps future work aligned with the established theme without copying the reference images.

## The feeling to preserve

Quiet, capable, tactile, and trustworthy. The app is an assistive instrument for a consequential job task. It should reduce uncertainty and cognitive load, not look like a futuristic AI demo, generic consumer dashboard, or marketing site.

## Strong preferences

- Use deep charcoal and slate tonal layers, crisp borders, and high contrast instead of white surfaces, glass effects, or blurry shadows.
- Use bright accessible green for a live microphone and completed action; blue for active processing; yellow only for focus; red only for errors.
- Pair every color-coded state with short text, an icon, and accessible status semantics.
- Use Inter throughout: open, practical, large enough to read, and safe for Vietnamese diacritics.
- Keep a one-column mobile hierarchy: status, current task, next action.
- Prefer large full-width controls with text labels; make the voice action especially prominent and tactile.
- Explain real progress in simple language. The user should always know what the app is doing and what happens next.
- Prefer direct labels such as “Confirm this value”, “Edit this value”, and “Submit application” over vague “Continue” labels.
- Use a small number of intentional grouped surfaces, with open space and dividers instead of a grid of nested cards.

## Accessibility preferences

- Treat visible text, TalkBack, TTS, haptics, focus, and color as coordinated expressions of one state.
- Preserve 48 dp minimum targets, 56 dp fields, and a 72 dp primary voice action whenever space permits.
- Support 200% Android font scaling without hiding labels or actions.
- Keep visual and semantic reading order identical.
- Make waiting, retries, CAPTCHA hand-off, errors, and completion explicit.
- Never display, speak, retain, or summarize passwords, OTPs, security answers, payment details, or identifiers.

## Avoid

- Purple gradients, neon glows, glassmorphism, floating blobs, or generic “AI magic”.
- Color-only feedback, tiny low-contrast text, icon-only primary actions, or ambiguous button labels.
- Decorative motion that implies live listening or processing when it is not happening.
- Multi-column mobile layouts, cramped paired actions, dense dashboards, or invented product destinations that the codebase does not support.
- Bottom navigation, job feeds, saved-application areas, social proof, chat, or account systems until those capabilities actually exist.
- Massive hero spacing, AIDA sections, scroll-pinning, carousels, marquees, and other web-marketing patterns that do not serve this Android task flow.

## Future screen check

Before accepting a UI change, ask:

1. Does it expose only capabilities that the codebase actually has?
2. Can the user understand state and next action without color or motion?
3. Does it work at 200% text size and in TalkBack order?
4. Does it feel like a calm assistive tool rather than a copied reference or generic template?
