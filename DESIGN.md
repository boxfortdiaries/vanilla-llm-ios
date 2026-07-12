# DESIGN.md

Status: **Live** — sourced directly from `LLMApp/Theme/*.swift`, 2026-07-12

## What this is

The concrete values behind every design token this app uses: color, type, spacing, radius, motion timing.
`SPEC.md` §6 describes the *rule* ("use tokens, never raw values") — this document is the actual values,
kept in sync with the code.

**The code is the source of truth, not this file.** If `Theme/*.swift` changes, update this document to
match — never the other way around. Do not add a value here that isn't backed by an actual token in code.

---

## Colors — `Theme/Colors.swift`

All colors wrap Apple's system semantic colors (not custom Asset Catalog colors or raw RGB) — they get
Light Mode, Dark Mode, and Increased Contrast support for free. Never reference a raw color literal outside
this file.

| Token | Maps to | Notes |
|---|---|---|
| `Background.primary` | `.systemGroupedBackground` | Grouped, not plain — glass needs tonal contrast to refract against; on flat white it's nearly invisible |
| `Background.secondary` | `.secondarySystemBackground` | |
| `Background.tertiary` | `.tertiarySystemBackground` | |
| `Surface.primary` | `.systemBackground` | |
| `Surface.elevated` | `.secondarySystemBackground` | |
| `Surface.bubble` | `.systemGray5` | User-message bubble fill. Deliberately gray, not blue — blue read as too loud once the app went monochrome. gray5 (not gray4): a touch lighter reads better on the grouped canvas while still holding shape |
| *(no token)* "Surface.Glass" | `.glassEffect()` modifier | Not a color token — it's a material. Use the modifier directly wherever glass is called for |
| `Separator.subtle` | `.separator` | |
| `Separator.strong` | `.opaqueSeparator` | |
| `Text.primary` | `.label` | |
| `Text.secondary` | `.secondaryLabel` | |
| `Text.tertiary` | `.tertiaryLabel` | |
| `Text.inverse` | `.systemBackground` | |
| `Tint.primary` | `.accentColor` | |
| `Tint.secondary` | `.accentColor` at 60% opacity | |
| `Tint.cta` | `.label` | HIG-style adaptive black CTA fill — black in Light Mode, white in Dark Mode (same pattern as Sign in with Apple). Pair with `Text.inverse` for the label on top of it |
| `success` | `.systemGreen` | |
| `warning` | `.systemOrange` | |
| `error` | `.systemRed` | |
| `selection` | `.tertiarySystemFill` | |
| `streaming` | `.accentColor` | No dedicated system color for "generation in progress" — aliased to tint rather than inventing a new hue. Revisit if streaming needs to read as visually distinct from other tinted UI |

---

## Typography — `Theme/Typography.swift`

Dynamic Type text styles only — no custom fonts, no fixed point sizes. Every token scales automatically with
the user's preferred content size.

| Token | Style |
|---|---|
| `largeTitle` | `.largeTitle` |
| `title` | `.title` |
| `title2` | `.title2` |
| `headline` | `.headline` |
| `body` | `.body` |
| `callout` | `.callout` |
| `subheadline` | `.subheadline` |
| `footnote` | `.footnote` |
| `caption` | `.caption` |
| `caption2` | `.caption2` |
| `monospaced` | `.system(.body, design: .monospaced)` — code blocks and inline code |

---

## Spacing — `Theme/Spacing.swift`

Never use an arbitrary spacing value in a view — always reference one of these.

| Token | Value |
|---|---|
| `xxs` | 4pt |
| `xs` | 8pt |
| `sm` | 12pt |
| `md` | 16pt |
| `lg` | 24pt |
| `xl` | 32pt |
| `xxl` | 48pt |
| `xxxl` | 64pt |

---

## Corner Radius — `Theme/Radius.swift`

| Token | Value |
|---|---|
| `small` | 12pt |
| `medium` | 18pt |
| `large` | 24pt |
| `xlarge` | 32pt |
| `capsule` | `.infinity` — fully rounded; `RoundedRectangle` clamps any radius larger than half the shortest side, so this reliably produces a capsule without a separate shape type |

---

## Motion — `Theme/Animation.swift`

Springs are tuned specifically to avoid visible bounce/overshoot — this was a deliberate original spec
constraint (see `SPEC.md` §6.9), not an accident of the default values.

| Token | Value |
|---|---|
| `fastDuration` | 0.15s |
| `standardDuration` | 0.22s |
| `slowDuration` | 0.35s |
| `pressScale` | 0.97 — scale-down on button press (spec §18.3) |
| `contextMenuDelay` | 0.5s |
| `cursorBlinkInterval` | 0.5s — streaming cursor blink (spec §18.11) |
| `fast` | `.spring(response: 0.15, dampingFraction: 0.9)` |
| `standard` | `.spring(response: 0.22, dampingFraction: 0.86)` |
| `slow` | `.spring(response: 0.35, dampingFraction: 0.82)` |

**Reduce Motion:** `AppAnimation.resolve(_:reduceMotion:)` is the single chokepoint every call site should
go through — never branch on `accessibilityReduceMotion` ad hoc. When Reduce Motion is on, any spring
resolves to `.easeInOut(duration: 0.22)` (the standard duration) instead — spring → ease, movement → fade,
per spec §18.1.

**Known one-off, not a token:** the drawer's full-panel slide uses `slow` (0.35s) rather than `standard` —
subtler than the default felt right for a surface that large. Recorded in code (`RootView.swift`) rather
than promoted to its own token, since it's a single deliberate exception, not a pattern.
