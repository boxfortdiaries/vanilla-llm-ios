# SPEC.md

Status: **Reconstructed**, 2026-07-12

## What this is

This is not the original spec. The original was written collaboratively before this project's first
commit, guided nearly every architectural and component decision in the initial build, and was cited
constantly in code comments as `spec §X.Y` — but was never saved to a file. That session is gone.

This document was rebuilt from the inside out: every `spec §X.Y` comment across the codebase (89 citations,
60 files, 42 distinct section numbers) was extracted and grouped back into sections. Where a section number
has no surviving citation anywhere in the code, it is listed as a gap rather than invented — there is no
way to know what it said, and guessing would make this document less trustworthy than having a hole in it.

**Going forward:** this file (plus `DESIGN.md` and `CONVERSATION-ARCHITECTURE.md`) should be written *during*
project setup, before the first line of implementation code — not reconstructed after the fact. Comments
can keep citing sections like `spec §6.1`, but only because the section actually exists here to check
against.

## Related documents

- **`DESIGN.md`** — the actual values for every design token this document's §6 only describes the
  *existence* of (colors, type, spacing, radius, motion durations). Don't duplicate values here.
- **`CONVERSATION-ARCHITECTURE.md`** — the authoritative, canonical spec for conversation behavior (viewport,
  motion, scroll ownership, keyboard coordination, composer, lifecycle, streaming, history navigation,
  accessibility, performance, extension rules). Supersedes this document wherever the two overlap (§13.2,
  §18.7, §18.8, §18.11, §19.3, §20.4) — drafted 2026-07-12 as a from-scratch behavioral architecture, not a
  reconstruction, so it's the trustworthy source on those topics, not this document. Replaces the earlier
  `CONVERSATION_ENGINE.md` (deleted).

---

## Guiding Principle (evidenced once — "Agent Constitution")

One citation (`Theme/Colors.swift`) references an "Agent Constitution" decision order used to choose between
implementation options: **native → simpler → accessible → maintainable → reusable**, in that priority order.
No other reference to this elsewhere in the code — likely a standing rule from the original setup
conversation rather than a section of this spec. Recorded here since it's the closest thing to a first
principle this codebase names explicitly.

---

## §6 — Component Philosophy

Reuse and compose rather than duplicate. Recurring rule across many components: if two things describe the
same visual pattern, they are the same component, not two.

Evidenced consolidations: `ConversationCell` absorbs a separately-named `PinnedConversation` (pinning is a
property of a conversation, not a different row type). `SettingsRow` absorbs `ToggleRow`. `Chip` absorbs
`Tag`, `Chip`, and `Token` (three names for one capsule-label pattern). `StreamingMessage` reuses `Message`'s
own status enum rather than a parallel "StreamState" enum.

Components own **temporary UI state only** — never business logic, never navigation intent (the caller
decides what an action does), never a duplicate of state that already lives on a model.

### §6.1 — Colors
Semantic tokens only, wrapping Apple's system colors — never raw RGB or `UIColor` literals outside the
token file. `Surface.Glass` is a material (`.glassEffect()`), not a color token. → values in `DESIGN.md`.

### §6.2 — Typography
Dynamic Type text styles only, no custom fonts — every call site scales with the user's content-size
preference automatically. Code blocks and inline code use a monospaced variant. → values in `DESIGN.md`.

### §6.3 — Spacing
Token-only spacing, never arbitrary values in a view. → values in `DESIGN.md`.

### §6.4 — Corner Radius
Fixed radius scale, never mixed outside it. → values in `DESIGN.md`.

### §6.7 — Dividers / Separators
1pt hairline, subtle separator color. Never stack border + shadow + fill for depth.

### §6.8 — Icons
SF Symbols exclusively — no custom iconography or user photos. An icon never replaces an accessibility
label when ambiguity exists; a label is required, not optional.

### §6.9 — Motion Tokens
Fixed duration/spring scale, tuned specifically to avoid visible bounce/overshoot. → values in `DESIGN.md`.

### §6.10 — Haptics Discipline
Moderate use only. Haptics fire on terminal transitions (success/failure), never continuously (e.g. never
once per streamed word).

### §6.11 — Floating Controls
Floating/inline contextual controls use glass material (`GlassToolbar`), distinct from the top-of-screen
navigation bar (`GlassNavigationBar`).

### §6.14 — Composition & Statelessness Rules
Components compose smaller primitives rather than re-implementing their visual style (e.g. `CitationChip`
composes `Chip`, `ArtifactToolbar` composes `GlassToolbar`). Components that need caller-provided behavior
(e.g. `ModelSelector`, `AttachmentButton`) take an action closure and own no navigation logic themselves.

---

## §7 — Navigation

### §7.1 — Stack-Based, Not Tab-Based
The app navigates via `NavigationStack` + `NavigationPath` (owned by `Router`, injected via environment,
never a singleton) — not a tab bar. A `FloatingTabBar` component exists in the codebase per a full
component-inventory pass, but is explicitly not wired into navigation.

---

## §8 — Content Conventions

- **§8.2** — Conversation preview text conventions (used by list/cell previews).
- **§8.3** — `ConversationView` is explicitly named the primary/core application experience — the surface
  everything else in the app supports.
- **§8.4** — An "Artifact" is defined as *focused generated content* — a document, code, or table — as
  distinct from a regular chat message.

---

## §9 — MessageActionsMenu

Message-level actions (surfaced via long-press context menu and the post-completion message toolbar) are
grouped into one type rather than passed around as individual closures.

---

## §11 — Error Recovery

Every recoverable error gets: a human-readable explanation (never a raw error code or `Error` type surfaced
to the UI layer) and a retry action. Views that render errors take an already-humanized message string —
they don't know what a status code is.

---

## §12 — Loading

Loading states are regional, never full-screen-blocking. A loading affordance belongs to the card, row, or
list footer it describes — not a modal that blocks the whole screen. Row-shaped content prefers a skeleton
over a spinner.

---

## §13 — Screen & Component Catalog

### §13.1 — Elevated / Floating Surfaces
Depth comes from material (glass), never from a shadow + border stack. Covers `GlassCard` (elevated
container), `GlassNavigationBar` (custom floating top bar, replacing system nav chrome), and `FloatingButton`
(primary contextual action, e.g. "New Chat").

### §13.2 — Conversation & Message Rendering
**See `CONVERSATION-ARCHITECTURE.md` — that document is authoritative here.** Its Streaming System (§9) and
Viewport/Boundary Physics sections (§2) define the target behavior; the current implementation (streaming
reveal, scroll-boundary recovery) predates that document and has known gaps against it, not yet reconciled.

Evidenced rules not superseded: assistant messages render readable-first — full-width text/markdown, no
bubble background/container. User messages get a bubble (system-gray fill, not blue — revised from an
original neutral fill that "vanished on the grouped canvas" once the app went monochrome). A three-dot
"thinking" indicator communicates assistant activity before text arrives — its accessibility label says
"Thinking," never "Typing"; the spec is explicit this must never imply a human is typing.

### §13.3 — Composer / Prompt Input
The single most important component in the app, per its own doc comment. Uses native
`TextField(_:text:axis:.vertical)` for auto-expand/multiline/paste — no custom text editor. The send button
morphs into a stop action while generating, via native `contentTransition(.symbolEffect(.replace))`.

### §13.4 — Conversation List Row & Search
Conversation preview rows show a "Status" indicator for whether the last message needs the user's
attention. Global search focuses instantly on appear.

### §13.5 — Artifact Workspace
Editing should feel native, avoiding web-editor patterns — uses native `TextEditor` for text/markdown/code.

### §13.6 — Search Scope & Results
Search scope changes via `Chip`-composed filter controls; results render as a dedicated result row type.

### §13.7 — Settings
Native grouped-list (`Section` inside `List`) pattern — explicitly avoid card-style settings rows.

---

## §18 — Motion & Interaction

### §18.1 — Reduce Motion
Springs replaced with ease curves, movement replaced with fades, wherever `accessibilityReduceMotion` is on.
Resolved centrally (`AppAnimation.resolve`), never branched ad hoc at each call site.

### §18.3 — Press Feedback
Scale-down press feedback (0.97 scale, spring return) — one shared button style, not a custom animation
per button. → exact values in `DESIGN.md`.

### §18.4 — Context Menus
Native `contextMenu` only — no custom-built menu surfaces.

### §18.7 — Return To Latest
See `CONVERSATION-ARCHITECTURE.md` §4.8–§4.10 (Scroll Ownership: Return To Live Conversation) and §10.8–§10.10
(History Navigation: Returning to Live) for full behavior.

### §18.8 — Keyboard Avoidance
"Never fight the keyboard" — achieved via native `safeAreaInset`, not custom keyboard-tracking. See
`CONVERSATION-ARCHITECTURE.md` §6 (Keyboard Coordination System).

### §18.11 — Streaming Cursor
500ms blink interval, opacity transition, fades on completion. See `CONVERSATION-ARCHITECTURE.md` §9
(Streaming System) for how this interacts with the (deliberately non-literal) streaming reveal.

### §18.12 — Sheet Header Pattern
Standard sheet header shape: header, content, primary action.

### §18.15 — Haptics
Success Notification on completed generation, Error Notification on a failed action — terminal transitions
only (ties back to §6.10).

### §18.19 — Motion Tokens
Referenced only alongside §6.9/§18.1 — no independent content found. → values in `DESIGN.md`.

**Known gap:** §18.2, §18.5, §18.6, §18.9, §18.10, §18.13, §18.14, §18.16–§18.18, §18.20+ have no surviving
citation. §18 clearly had more content than what's reconstructed here.

---

## §19 — Architecture

### §19.1 — Persistence
Real backing store should be SwiftData. Current prototype uses an injected in-memory store
(`ConversationStore`) seeded from `SampleData`.

### §19.3 — Screen-Level Generation State
See `CONVERSATION-ARCHITECTURE.md` §8 (Conversation Lifecycle System) and §9 (Streaming System) for the
canonical state model. Per-message status (draft/streaming/failed/etc.) lives on `Message` itself; a
separate, smaller enum covers only screen-level idle/generating.

### §19.4 — State Ownership Boundaries
`AppState` owns only what outlives a single screen — global preferences, appearance, routing. Screen-local
state (including generation logic) lives in that screen's own ViewModel, reading/writing through a shared
store rather than owning a private copy.

### §19.6 — Data Models
`Conversation`, `Message`, `Attachment`, `Artifact` are the core models.

### §19.7 — AIService Capability
A protocol boundary for generating assistant responses. `MockAIService` is the only conformer in the
prototype; a real API-backed implementation should mean writing one new conforming type, not touching call
sites.

### §19.8 — Composition Root
One composition root (`AppContainer`) constructs app-wide state/services once at launch and hands them out
via SwiftUI environment. No singletons, no global mutable state, no hidden dependencies.

### §19.9 — Sample / Seed Data Requirements
Seed data is a first-launch experience, not test fixtures (there's no backend yet). It must demonstrate:
a failed message (error recovery UI), and a long conversation (20+ messages, for scroll-performance and
auto-scroll testing).

**Known gap:** §19.2, §19.5 have no surviving citation.

---

## §20 — Error Handling

### §20.4 — Error Recovery Scope
Errors surface as a failed message with retry, not a full-screen error state — "error recovery" is treated
as a per-message concern (ties back to §11).

**Known gap:** §20.1–§20.3, §20.5+ have no surviving citation.

---

## Appendix E — Message Lifecycle

`MessageStatus` distinguishes `retrying` from `failed` specifically so the UI can show an active retry
attempt rather than a dead end. Full status set (from `Message.swift`): draft/sending → streaming → complete
| failed | interrupted, with `retrying` as a distinct in-flight state layered over a prior `failed`.

---

## Known gaps (sections cited nowhere, content presumed lost)

§1–§5, §10, §14–§17, most of §18 (see above), §19.2, §19.5, §20.1–§20.3 and §20.5+.

If a future comment ever cites one of these, don't guess at surrounding content — add only what that new
citation actually says, and note it as a fresh addition, not a recovered original.
