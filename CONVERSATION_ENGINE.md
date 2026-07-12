# CONVERSATION_ENGINE.md

Version: 2.1 (adapted for LLM-iOS from the 2.0 draft)

## Purpose

This document defines the conversational interaction engine for the application.

It is intentionally independent of visual design.

It defines:

* Conversation behavior
* Viewport management
* Scroll ownership
* Keyboard coordination
* Message lifecycle
* Streaming behavior
* Reading flow
* Spatial consistency

This document is the authoritative specification for how the conversation behaves.

If any implementation differs from these behaviors, the implementation should be considered incorrect —
**except** where a difference is explicitly recorded in §11 as a deliberate, tested deviation. Those
deviations are not gaps to close; they are the spec, corrected by what actually shipped.

This document is scoped to conversation behavior only. It is a sibling to `SPEC.md` (architecture,
component philosophy, error handling — reconstructed from in-code `spec §X.Y` citations after the original
was lost) and `DESIGN.md` (color, typography, spacing, motion token values). Where this document and
`SPEC.md` describe the same surface (message rendering, streaming, keyboard, return-to-latest), this
document wins — it was written with direct implementation cross-checks, `SPEC.md` was reconstructed from
comments alone.

---

# 1. DESIGN PHILOSOPHY

Conversation is not a document.

Conversation is not an infinitely scrolling feed.

Conversation is a live interaction space.

The interface exists to help the user think, not to manage content.

The user should never need to think about scrolling, positioning, or layout.

The conversation engine is responsible for those decisions.

---

# 2. VIEWPORT INVARIANTS

Viewport Invariants are permanent behavioral guarantees.

These rules always remain true.

Every implementation decision must preserve them.

If an implementation violates an invariant, it is incorrect regardless of technical convenience.

## 2.1 Conversation Stability

The conversation always feels spatially anchored.

It should never feel as though it is drifting through an infinite document.

Movement only occurs when it communicates meaningful change — such as a new exchange taking its place at
the top of the viewport (see §3, `pinLatestTurn`).

---

## 2.2 Composer Boundary

The composer is never part of the scrollable conversation.

It permanently defines the lower interaction boundary.

Conversation exists above it.

*(Implemented via `.safeAreaInset(edge: .bottom)` in `ConversationView` — the composer is structurally
outside the `ScrollView`, not visually clipped to look that way.)*

---

## 2.3 Keyboard Coordination

The keyboard is part of the conversation layout.

It is never treated as an overlay.

Conversation, composer, and keyboard move together as one coordinated system.

The keyboard never obscures active conversation.

---

## 2.4 Scroll Ownership

Exactly one entity owns scrolling.

Ownership belongs to either:

* System
* User

Ownership is never shared.

Automatic scrolling immediately stops once the user intentionally scrolls away from the live conversation.

**Exception:** sending a message is treated as a fresh anchor point, not a continuation of passive
reading. It always pins the new exchange to the top regardless of where the user was previously scrolled —
this is a deliberate re-assertion of System ownership, not a violation of it. See §3.

---

## 2.5 Live Conversation

While the system owns scrolling:

The active exchange remains visible.

New content enters naturally.

The user never manually repositions the viewport during normal conversation.

---

## 2.6 Historical Context

History exists for reference.

The interface prioritizes the current exchange.

Older messages naturally move out of the active reading area as the conversation progresses.

History remains instantly accessible but never competes with the present conversation.

---

## 2.7 Message Continuity

Assistant responses are continuous.

The reply is a single message from the moment it begins generating to the moment it completes — there is
never a second, temporary message swapped in for it.

**How this is satisfied here:** generation and reveal are decoupled (see §5). Content accumulates in the
background as it generates; the interface does not render that growth. The single assistant message
transitions Thinking → (generating, hidden) → Completed (revealed) without ever being replaced by a
different message.

---

## 2.8 Layout Stability

The viewport remains visually stable.

The following actions must never unexpectedly reposition content:

* Keyboard appearance
* Keyboard dismissal
* Composer expansion
* Streaming
* Response completion
* Regeneration
* Device rotation

*(This app's hidden-until-complete generation, §5, is partly in service of this invariant: a bubble's true
size is unknown until content is final, so revealing it only once complete — rather than growing it live —
removes every intermediate reflow that live-token rendering would otherwise cause.)*

---

## 2.9 Return To Latest

The Return To Latest control exists only while:

The user owns scrolling.

Selecting it immediately returns scroll ownership to the system.

The control disappears automatically.

---

## 2.10 Bottom Boundary

The interaction boundary is always the composer — the conversation never intentionally holds scrollable
space that serves no purpose.

**Amended for this app:** a fixed, non-reactive reserve of empty space below the messages is permitted
*specifically* in service of pinning the latest exchange to the top of the viewport (see §3). It must be:

* A constant size (a fraction of viewport height), never measured or resized reactively during a turn's
  lifetime.
* Present from the moment any message exists, and never removed or shrunk once added.

This exception exists because the alternative was tried and failed: removing or shrinking the reserve after
a reply completes forces the scroll offset to clamp back to fit the now-smaller content, which yanks the
pinned message back down and reveals the previous turn. This was verified directly and reproduced reliably.
A reserve that never changes size avoids the clamp entirely.

What §2.10 still forbids: empty space that grows, that appears without a pinning purpose, or that the user
can scroll into and get "stuck" past the last real message with no way to tell they've overshot (see
`ConversationList`'s "at bottom" detection, which discounts the reserve for exactly this reason).

---

## 2.11 Reading Priority

The interface always prioritizes:

1. Current user message
2. Current assistant response
3. Generating response
4. Immediate context

Older content should naturally leave the viewport without feeling lost.

---

## 2.12 Performance

Behavior never changes because conversation length increases.

Ten messages and one thousand messages should feel identical.

Performance optimizations must never change interaction behavior.

---

## 2.13 Accessibility

Every gesture has an accessible equivalent.

Generation-in-progress is announced.

Conversation remains predictable using VoiceOver.

**Status: not yet implemented.** There is currently no VoiceOver announcement for the generating → complete
transition. Tracked as an open gap, not a conflict — see §11.

---

## 2.14 Platform

Prefer native iOS behavior whenever possible.

Custom interaction should only exist when no equivalent native behavior exists.

*(Keyboard avoidance, in particular, uses plain `safeAreaInset` rather than a custom keyboard-tracking
layer — see §2.2.)*

---

## 2.15 Viewport Predictability

The user should always know where the next piece of content will appear.

Every interaction follows the same spatial rhythm.

Consistency is more important than animation.

---

## 2.16 Spatial Memory

The interface should preserve the user's mental model.

The user should never lose track of where they are within the conversation because of automatic movement.

The system should avoid unnecessary repositioning.

---

# 3. SCROLL OWNERSHIP MODEL

The conversation engine operates using two exclusive ownership states.

## System Owned

The application controls viewport position.

Used during:

* Normal conversation
* Message send (the new exchange is pinned to the top of the viewport — see `pinLatestTurn` in
  `ConversationList` — regardless of the user's prior scroll position; sending re-asserts System ownership)
* Response generation
* Message insertion

The viewport follows new content automatically.

---

## User Owned

Triggered when the user intentionally scrolls away from the live conversation.

The system immediately relinquishes control.

Generation continues.

Viewport position remains fixed.

The application never attempts to "pull" the user back to the live conversation.

---

## Ownership Returns

System ownership resumes only when:

* The user manually returns to the live conversation
* The user taps Return To Latest

Ownership transitions should be immediate and predictable.

---

# 4. MESSAGE LIFECYCLE

User messages appear immediately.

No server acknowledgment is required before insertion.

Assistant generation begins immediately afterward, once the user message has settled into its pinned
position (see §3) — held briefly so the reply can't start mid-scroll and disrupt it.

Assistant responses transition through:

Thinking

↓

Streaming (generating — content accumulates, but stays visually hidden; see §5)

↓

Completed (revealed)

The assistant reply is one message throughout. Generation never creates a second, temporary message.

---

# 5. STREAMING

**Streaming, in this app, is a data-layer concept — not a visual one.**

Content accumulates in the background exactly as it arrives from the model. The interface does not render
that growth. The reply stays visually hidden behind a generating cursor for the full duration of generation.
Once generation completes, the full response reveals in a single continuous top-to-bottom cascade
(`CascadeRevealRenderer`, driven by `MarkdownView`'s per-block stagger).

This is a deliberate reversal of literal token-by-token rendering. Both were tested: word-by-word reveal
read as a typewriter effect; complete-then-cascade reads as considered, arriving rather than trickling in.
It also serves §2.8 — a bubble's true height is only known once content is final, so nothing reflows mid-
generation.

Rules:

* The reply must never appear to "type" character by character.
* The cascade reveal plays once, only for a reply that just finished generating in the current session —
  never replayed for a message loaded already-complete from history, and never replayed if the message
  scrolls back into view.
* Reduce Motion disables the cascade; content appears immediately at full opacity, no animation.
* Generation continues normally if the user has scrolled away (User Owned, §3) — nothing pulls them back
  when it completes.

---

# 6. RETURN TO LATEST

The Return To Latest control represents the transition back into the live conversation.

Behavior:

* Appears only when the viewport is detached from the live conversation
* Remains visible while detached
* Scrolls smoothly to the newest exchange
* Restores System scroll ownership
* Dismisses automatically after arrival

The control should never appear during normal conversation.

---

# 7. KEYBOARD COORDINATION

The keyboard is part of the conversation engine.

When the keyboard appears:

* The conversation adjusts
* The composer remains attached
* Reading position is preserved

When the keyboard disappears:

* Layout expands naturally
* Existing content remains stable
* No sudden jumps occur

Growing the composer must not unexpectedly move conversation content.

Sending a message dismisses the keyboard at essentially the same instant as the pin-to-top scroll (§3)
fires — the pin re-checks itself once the keyboard's resize completes, so it lands correctly against the
final viewport size rather than the momentarily-smaller pre-dismiss one.

---

# 8. READING FLOW

The conversation engine should continuously optimize for the current exchange.

The user's eyes should naturally remain on:

* Their latest message
* The assistant's active response

Historical messages gradually leave the active reading area as the conversation progresses.

The user should rarely need to manually reposition the conversation during active interaction.

---

# 9. STATE MACHINES

## Conversation

Idle

↓

Typing

↓

User Message

↓

Thinking

↓

Streaming (hidden generation)

↓

Completed (revealed)

↓

Idle

---

## Scroll Ownership

System Owned

↓

User Scroll

↓

User Owned

↓

Return To Latest

↓

Animated Return

↓

System Owned

---

# 10. IMPLEMENTATION SUCCESS

The conversation engine is successful when:

* Users rarely think about scrolling
* Keyboard movement feels native
* Generation completion feels considered, not mechanical
* Layout never surprises the user
* The current exchange is always the visual priority
* Historical content remains available without competing for attention
* The interface develops a consistent spatial rhythm
* Users build unconscious trust in where content will appear

The conversation should ultimately disappear as an interface.

The user's attention should remain entirely on the conversation itself.

---

# 11. IMPLEMENTATION NOTES & KNOWN GAPS

Traceability from invariant to code, and an honest record of what's proven vs. what's still open —
so this stays a living document rather than an aspirational one.

| Behavior | File | Status |
|---|---|---|
| Composer boundary (§2.2) | `ConversationView.swift` (`safeAreaInset`) | ✅ Shipped |
| Pin-to-top on send / scroll reserve (§2.10, §3) | `ConversationList.swift` (`reserveHeight`, `pinLatestTurn`) | ✅ Shipped — reserve size is empirically tuned (`viewportHeight * 0.4`), re-tune if reply lengths change materially |
| Return to Latest (§6) | `ConversationView.swift` (chevron button + `scrollToBottomTrigger`) | ✅ Shipped |
| Hidden-until-complete generation + cascade reveal (§5) | `StreamingMessage.swift`, `CascadeRevealRenderer.swift`, `MarkdownView.swift` | ✅ Shipped, deliberately deviates from literal "live streaming" — see §5 |
| Keyboard-resize re-pin (§7) | `ConversationList.swift` (`awaitingKeyboardSettle`) | ✅ Shipped |
| Reduce Motion fallback | `StreamingMessage.swift` / `MarkdownView.swift` (`reduceMotion`) | ✅ Shipped |
| VoiceOver announcement for generation (§2.13) | — | ⬜ Not implemented — no accessibility announcement currently fires on the Thinking → Completed transition |
| Explicit ownership-state enum (§3, §9) | — | ⬜ Ownership is currently implicit (`isAtBottom` bool + one-shot pin calls), not a named state machine. Works today; formalize only if a third ownership case is ever needed (YAGNI) |

## Deliberately reconciled deviations from the original draft

Two invariants in the original ChatGPT draft (v2.0) were written as absolutes that this app's tested,
shipped behavior contradicts. Both were reconciled by amending the invariant to match reality, not by
changing the code:

1. **§5 Streaming** — the draft called for literal live token rendering. This app hides generation and
   reveals it complete, by deliberate, user-verified design choice (word-by-word read as a typewriter).
2. **§2.10 Bottom Boundary** — the draft forbade any scrollable empty space below the conversation. This
   app permanently reserves a fixed fraction of the viewport for that exact purpose, because removing it
   was tried and reliably broke the pin-to-top layout (verified via reproduced regression).

If either behavior is revisited in the future (e.g. a redesign that drops the ChatGPT-style pin-to-top
layout), these amendments should be the first things reconsidered — they exist to serve that specific
layout, not as independent goals.
