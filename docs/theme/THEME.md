---
name: Aura Tactile Access
colors:
  surface: '#101417'
  surface-dim: '#101417'
  surface-bright: '#363a3d'
  surface-container-lowest: '#0b0f12'
  surface-container-low: '#181c1f'
  surface-container: '#242b30'
  surface-container-high: '#262a2e'
  surface-container-highest: '#313539'
  on-surface: '#e0e3e7'
  on-surface-variant: '#becbb3'
  inverse-surface: '#e0e3e7'
  inverse-on-surface: '#2d3134'
  outline: '#88957f'
  outline-variant: '#3f4a38'
  surface-tint: '#69e043'
  primary: '#69e043'
  on-primary: '#0b3900'
  primary-container: '#39b00e'
  on-primary-container: '#0b3a00'
  inverse-primary: '#1d6d00'
  secondary: '#83d0fc'
  on-secondary: '#00344a'
  secondary-container: '#006d95'
  on-secondary-container: '#c8e9ff'
  tertiary: '#bfc8cb'
  on-tertiary: '#293235'
  tertiary-container: '#929b9e'
  on-tertiary-container: '#2a3336'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#85fd5d'
  primary-fixed-dim: '#69e043'
  on-primary-fixed: '#042100'
  on-primary-fixed-variant: '#145200'
  secondary-fixed: '#c4e7ff'
  secondary-fixed-dim: '#83d0fc'
  on-secondary-fixed: '#001e2c'
  on-secondary-fixed-variant: '#004c69'
  tertiary-fixed: '#dbe4e7'
  tertiary-fixed-dim: '#bfc8cb'
  on-tertiary-fixed: '#141d20'
  on-tertiary-fixed-variant: '#3f484b'
  background: '#101417'
  on-background: '#e0e3e7'
  surface-variant: '#313539'
  surface-base: '#121619'
  surface-raised: '#1a1f24'
  text-primary: '#ffffff'
  text-secondary: '#d5dbde'
  text-muted: '#9eabb0'
  state-listening: '#39b00e'
  state-processing: '#18769e'
  state-inactive: '#4b5457'
  focus-outline: '#ffff00'
  status-error: '#ff5252'
typography:
  display:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 22px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.04em
  status-pill:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '800'
    lineHeight: 20px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  margin: 1rem
  margin-tablet: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system is engineered for low-vision and blind job seekers, alongside sighted allies operating under Universal Design principles. The brand voice is respectful, quiet, and empowering. It removes cognitive exhaustion by stripping away visual clutter, ad-tech aesthetics, and decorative novelties in favor of unambiguous clarity and mechanical predictability.

The aesthetic fuses **Utilitarian Minimalism** with **Tactile Intentionality**:
- Surfaces are anchored in deep, battery-conserving true darks to minimize light-bleed glare for photophobic low-vision users.
- Interactive controls use generous touch envelopes, crisp structural borders, and unmistakable focal indicators.
- Information architecture treats auditory narration (TTS), tactile haptics, and visual representations as equal, simultaneous outputs. Visual elements never rely on color alone to communicate state.

## Colors

The color palette is built strictly around high contrast (surpassing WCAG 2.2 Level AA requirements, achieving AAA contrast ratios above 7:1 for text) and explicit functional states:

- **Surface Base (`#121619`)**: A deep slate tone that preserves OLED power efficiency while eliminating the stark optical halation produced by pure `#000000` against bright glyphs.
- **State: Listening (`#39b00e`)**: Vibrant accessible green with strong chroma, paired with solid black text or structural outer halos to signal hot mic capture.
- **State: Processing (`#18769e`)**: Deep maritime cyan indicating background analysis, intent parsing, or synthetic thought.
- **State: Inactive / Structural Accent (`#4b5457`)**: Slate dark neutral for idle interaction rings, secondary borders, and passive layout dividers.
- **Focus Indicator (`#ffff00`)**: Pure high-visibility accessible yellow, reserved exclusively for Android TalkBack selection envelopes and hardware focus states (providing >10:1 contrast against dark background tiers).

Color is strictly secondary to linguistic and haptic status: all colored status chips and voice state transitions must be paired with visible typography and screen-reader live announcements.

## Typography

The design system utilizes **Inter** across all UI tiers for its open counter shapes, unambiguous character differentiation (e.g., distinguishing uppercase `I`, lowercase `l`, and digit `1`), and reliable tabular figures.

Typography rules:
- **Scaling without degradation**: All text containers must dynamically expand without truncation or horizontal clipping when Android system font scaling or Flutter's `textScaleFactor` scales up to 200%.
- **Minimum font floor**: Interactive labels and critical content never fall below 14px equivalent, ensuring immediate legibility under reduced vision acuity.
- **Weights for hierarchy**: Semibold (600) and Bold (700/800) weights establish direct visual anchors, allowing low-vision users scanning with high magnification or peripheral vision to instantly detect heading levels.
- **Language support**: Supports complete extended Latin and Vietnamese diacritics natively without vertical metric clipping or line-height overlap.

## Layout & Spacing

Layout adheres to a single-column fluid model optimized for handheld thumb ergonomics and screen-reader traversal order:

- **Touch Boundary Enforcement**: Interactive elements possess a hard physical bounding box of at least 48×48dp, with primary triggers scaling to 56dp or full screen widths.
- **Linear Reading Stream**: Avoid multi-column complexity on mobile. Elements flow top-to-bottom in a clear semantic sequence: Global Controls (Language/Settings) $\rightarrow$ Live Accessibility Status & Transcript $\rightarrow$ Dynamic Workspace $\rightarrow$ Large Voice Action Pad.
- **Safe Area Insets**: Full support for Android system navigation bars and gesture cutouts using explicit bottom padding anchors of `space-xl` (32dp) to prevent accidental OS dismissals during voice activation.

## Elevation & Depth

Visual depth is communicated exclusively through **Tonal Layers** and **High-Contrast Structural Borders**, rejecting diffuse, low-contrast drop shadows which blur boundary clarity for users with astigmatism or macular degeneration:

1. **Surface Base (`#121619`)**: Ground canvas tier.
2. **Surface Raised (`#1a1f24`)**: Transcript monitors and application cards; separated from the base by a solid 1.5px border in `#4b5457`.
3. **Surface Interactive / Focus Tier**: Elements focused via TalkBack or directional gestures gain a solid 3px outline in `#ffff00` with an immediate 2px internal negative space.
4. **Scrim & Modal Shields**: Solid 85% opacity `#121619` overlay, eliminating background distractions to keep assistive focus bounded within the active dialog.

## Shapes

The design system adopts a **Rounded** shape profile (`roundedness: 2`). Standard rectangular elements feature 0.5rem (8px) corners, medium containers feature 1rem (16px), and primary cards/interactive pads feature 1.5rem (24px).

Pill-shaped geometries are reserved strictly for the status announcer badges and language toggles. Distinct shape signatures allow low-vision users to perceive component roles through silhouettes alone before reading the text label.

## Components

### 1. Voice Trigger Action Pad (Primary Control)
- **Geometry**: Expansive button spanning 100% width with a minimum height of 72dp (or full lower-third touch zone).
- **Idle State**: Background `#242b30`, border 2px solid `#4b5457`, text and icon in `#ffffff`.
- **Listening State**: Background `#39b00e`, text `#121619`, pulsating high-visibility ring. Accompanied by tactile single haptic thump and immediate `Semantics(liveRegion: true)` narration.
- **Processing State**: Background `#18769e`, text `#ffffff`, animated striped high-contrast sweep pattern. Accompanied by periodic haptic ticking.

### 2. High-Contrast Status Pill & Transcript Container
- **Status Pill**: Compact badge with uppercase bold text (`#ffffff` on `#18769e` or `#121619` on `#39b00e`) containing an explicit icon prefix (e.g., ear, brain, checkmark) so state is never reliant on color alone.
- **Transcript Box**: Raised container (`#1a1f24`) with a 1.5px outline (`#4b5457`). Displays live speech-to-text outputs and AI responses with high-contrast text (`#ffffff` at 18px body-lg). Configured as an accessible live region for TalkBack auto-readout.

### 3. Language Switcher (VI / EN Toggle)
- **Dimensions**: Segmented pill control with minimum 48dp touch height.
- **Active State**: Solid high-contrast fill (`#ffffff`) with deep dark text (`#121619`).
- **Inactive State**: Deep neutral surface (`#121619`) with high-contrast text (`#d5dbde`) and 1.5px `#4b5457` boundary.
- **Accessibility**: Explicitly announced as `"Language toggle: English selected, double tap to switch to Vietnamese"`.

### 4. Form & Review Cards (Job Seeker Workflows)
- **Container**: Card layout with 1.5rem rounded corners, `#1a1f24` background, `#4b5457` outline.
- **Inputs**: Form fields provide 56dp height minimum, prominent 2px static borders, permanent visible floating labels (never disappearing placeholder text), and explicit validation icons (checkmark or alert cross).

### 5. Selection Controls (Checkboxes & Radios)
- **Touch Target**: 48×48dp bounding box with a 24×24dp visible stroke.
- **Visuals**: 2.5px heavy border with high-contrast checked states using solid fills and crisp checkmark glyphs.