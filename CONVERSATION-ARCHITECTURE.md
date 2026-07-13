# CONVERSATION_ARCHITECTURE.md

Version: 1.0

Status: Canonical

---

# 0. PURPOSE

This document defines the architecture of conversation within the application.

It is the authoritative specification governing how conversation behaves.

This document intentionally does **not** define:

* visual design
* component styling
* implementation details
* framework selection
* platform APIs

Those concerns belong elsewhere.

Instead, this document defines the behavioral architecture of conversation.

Every implementation decision must preserve the contracts established here.

If implementation and architecture disagree, the architecture is considered correct.

---

# 0.1 WHY THIS DOCUMENT EXISTS

Conversation is the primary product.

Everything else exists in service of conversation.

Historically, conversational interfaces have been implemented as scrollable collections of messages.

That model is insufficient.

A conversation is not a document.

A conversation is not a feed.

A conversation is not a list.

A conversation is a continuous interaction between a person and an intelligent system.

The architecture described here exists to preserve that interaction regardless of platform, implementation, or future product evolution.

---

# 0.2 DESIGN OBJECTIVE

The user should never think about:

* scrolling
* layout
* positioning
* keyboard behavior
* viewport management

The user should only think about:

* their question
* the current response
* what to ask next

Every architectural decision should reduce awareness of the interface.

---

# 0.3 ARCHITECTURAL PHILOSOPHY

The Conversation Architecture is built upon one principle:

**The interface should preserve the user's train of thought.**

Every system defined in this document ultimately serves that objective.

When competing implementation approaches exist, prefer the approach that minimizes interruption to the user's thinking.

---

# 0.4 DESIGN VALUES

The Conversation Architecture values:

Clarity over novelty.

Consistency over animation.

Predictability over surprise.

Reading over decoration.

Flow over features.

Continuity over transitions.

Native behavior over custom behavior.

These values should guide every implementation decision.

---

# 0.5 SUCCESS

The architecture is successful when users stop noticing the interface.

The interface should become transparent.

The user should feel as though they are thinking with the system rather than operating software.

---

# 1. SYSTEM MODEL

Conversation is composed of independent systems.

Each system owns a single responsibility.

No system should assume the responsibilities of another.

The Conversation Architecture consists of:

• Conversation System

• Viewport System

• Boundary Physics System

• Scroll Ownership System

• Keyboard Coordination System

• Reading Flow System

• Conversation Lifecycle System

• Presentation System

These systems cooperate but remain independent.

Their separation is intentional.

It allows the architecture to evolve without introducing unintended behavioral regressions.

---

# 1.1 SYSTEM RESPONSIBILITIES

## Conversation System

Owns the logical state of the conversation.

Responsible for:

* message sequence
* conversational continuity
* active exchange
* historical context

The Conversation System never manages layout.

---

## Viewport System

Owns what the user is currently reading.

Responsible for:

* visible region
* canonical alignment
* active reading area
* viewport state

The Viewport System never manages gesture interpretation.

---

## Boundary Physics System

Owns temporary displacement.

Responsible for:

* elastic boundaries
* recovery
* resting alignment
* transient interaction

Boundary Physics never changes conversation state.

Boundary Physics never changes viewport ownership.

---

## Scroll Ownership System

Owns navigation through history.

Responsible for:

* ownership transitions
* automatic following
* manual browsing
* returning to the live conversation

It never controls message rendering.

---

## Keyboard Coordination System

Owns interaction between:

* viewport
* composer
* keyboard

Its responsibility is continuity.

Not animation.

---

## Reading Flow System

Owns the user's visual attention.

Responsible for determining which information is naturally emphasized during every phase of conversation.

The Reading Flow System never modifies conversation state.

---

## Conversation Lifecycle System

Owns message progression.

Responsible for:

* sending
* thinking
* streaming
* completion
* interruption
* regeneration

It never modifies viewport behavior directly.

---

## Presentation System

Owns visual expression.

Responsible for:

* animation
* rendering
* transitions
* visual polish

Presentation never determines behavior.

It expresses behavior defined elsewhere.

---

# 1.2 INTERACTION HIERARCHY

All interaction follows a strict hierarchy.

User Intent

↓

Conversation State

↓

Viewport State

↓

Boundary Physics

↓

Presentation

Higher levels always take precedence over lower levels.

Presentation must never redefine behavior.

Boundary Physics must never redefine viewport state.

Viewport state must never redefine conversation state.

Conversation state must always reflect user intent.

This hierarchy is absolute.

It exists to prevent behavioral drift as the application evolves.

---

# 1.3 ENGINEERING PRINCIPLE

Behavior is defined exactly once.

Every behavior has a single owner.

Every owner has a single responsibility.

If multiple systems appear to control the same behavior, the architecture should be considered incorrect.

Responsibility must be reassigned until ownership is unambiguous.

---

# 1.4 CONSTITUTIONAL RULE

The architecture should become more stable as new features are added.

Voice.

Artifacts.

Attachments.

Search.

Editing.

Multimodal interaction.

Future capabilities must integrate into the existing architecture.

The architecture should not require new foundational concepts for each feature.

If a new feature requires redefining existing architectural principles, the feature should be reconsidered before the architecture is changed.

---

# 2. VIEWPORT SYSTEM

## Purpose

The Viewport System defines the user's active reading environment.

It is responsible for presenting the conversation in a way that preserves continuity, spatial memory, and focus.

The viewport is not a rendering surface.

It is not a scrolling container.

It is not a list.

The viewport is an interaction system whose purpose is to maintain the user's place within an ongoing conversation.

---

# 2.1 VIEWPORT RESPONSIBILITY

The Viewport System owns only one question:

**"What should the user be reading right now?"**

It is responsible for:

* The active reading region
* Canonical resting alignment
* Spatial continuity
* Reading stability
* Viewport state

It is not responsible for:

* Gesture interpretation
* Conversation state
* Message generation
* Animation timing
* Visual styling

Those responsibilities belong to other systems.

---

# 2.2 VIEWPORT PHILOSOPHY

The viewport exists to support thought.

It should never compete with the conversation.

The user should feel as though they are looking through the interface rather than at it.

Every movement of the viewport should reinforce the user's mental model of the conversation.

Movement should never exist solely because interaction occurred.

Movement must always communicate meaningful change.

---

# 2.3 ACTIVE READING AREA

The viewport contains a single Active Reading Area.

The Active Reading Area is the region where the user's attention naturally resides during normal conversation.

The Active Reading Area is not defined by fixed coordinates.

It is defined by the layout system.

Its position adapts naturally to:

* Device geometry
* Safe area
* Navigation environment
* Keyboard state
* Composer state
* Accessibility settings

Regardless of adaptation, the Active Reading Area should feel consistent across every interaction.

---

# 2.4 CANONICAL RESTING ALIGNMENT

The viewport has exactly one canonical resting alignment while following the live conversation.

This alignment represents the natural position of the active exchange.

Every new interaction begins from this alignment.

Every completed interaction returns to this alignment.

The canonical resting alignment is never defined by gesture input.

It is determined entirely by the layout system.

The implementation must maintain a single source of truth for this alignment.

No secondary system may redefine it.

---

# 2.5 SPATIAL MEMORY

The viewport must preserve the user's spatial memory.

Users should quickly develop an unconscious expectation of where conversation begins, where responses appear, and where attention should move.

This expectation is intentionally repetitive.

Consistency strengthens orientation.

Novelty weakens orientation.

The viewport should reinforce spatial memory through repetition rather than variation.

---

# 2.6 VIEWPORT PREDICTABILITY

Every new interaction follows the same spatial rhythm.

The user should always be able to predict:

* Where their next message will appear
* Where the assistant response will begin
* Where streaming will continue
* Where the completed exchange will settle

The viewport should never surprise the user with unexpected repositioning.

Predictability is more important than visual excitement.

---

# 2.7 VIEWPORT STABILITY

The viewport should remain visually stable throughout the conversation lifecycle.

The following events must not unexpectedly alter the user's reading position:

* Streaming progress
* Keyboard appearance
* Keyboard dismissal
* Composer growth
* Response completion
* Regeneration
* Device rotation
* Layout recalculation

Necessary movement should be minimal.

Unnecessary movement should never occur.

---

# 2.8 LIVE CONVERSATION

The live conversation is the present moment of interaction.

The viewport naturally prioritizes the live conversation over historical content.

While attached to the live conversation:

* The current user message remains visually prioritized.
* The active assistant response remains immediately adjacent.
* Streaming continues naturally within the current exchange.

The live conversation establishes the viewport's canonical resting alignment.

---

# 2.9 HISTORICAL CONVERSATION

Historical conversation exists for reference.

It does not define the viewport's natural resting state.

When the user intentionally navigates history:

The viewport temporarily leaves the live conversation.

The architecture must preserve the distinction between:

Following the conversation

and

Browsing the conversation.

These are fundamentally different interaction modes.

---

# 2.10 VIEWPORT STATES

The viewport operates within four primary states.

## Live

The viewport is following the active conversation.

The canonical resting alignment is active.

The system owns the viewport.

---

## Detached

The user has intentionally navigated away from the live conversation.

Historical messages become the user's focus.

The viewport no longer follows incoming content.

---

## Transitional

The viewport is moving between stable states.

Examples include:

* Returning to the live conversation
* Restoring canonical alignment
* Coordinating with keyboard transitions

A Transitional state is temporary.

It must always resolve into a stable state.

---

## Elastic

The viewport has been temporarily displaced beyond one of its natural boundaries.

The underlying viewport state has not changed.

Only its presentation has been temporarily displaced.

The Elastic state is transient.

It never becomes a resting state.

---

# 2.11 ELASTIC DISPLACEMENT

Elastic displacement exists to acknowledge user intent without redefining conversation state.

When the user reaches a natural boundary and continues interacting:

The viewport may temporarily displace.

This displacement is purely expressive.

It communicates the existence of a boundary.

It does not establish a new viewport position.

Elastic displacement is not navigation.

Elastic displacement is not scrolling.

Elastic displacement is not history browsing.

It is temporary presentation layered upon an otherwise unchanged viewport.

---

# 2.12 ELASTIC BOUNDARIES

The viewport defines two elastic boundaries. Each has its own canonical alignment
(revised per Dan, 2026-07-12 — superseding the single-shared-alignment rule this
section originally stated).

## Beginning Boundary

Represents the beginning of the conversation.

Temporary displacement beyond this boundary is permitted.

Upon release, the viewport returns to the **first message**, pinned at the same
top offset every canonical alignment uses.

---

## Live Boundary

Represents the current end of the live conversation.

Temporary displacement beyond this boundary is permitted.

Upon release, the viewport returns to the **last user message**, pinned at the
same top offset.

---

The two boundaries recover to different messages, but the same alignment rule
(pinned at the top offset) and the same elastic character (temporary
displacement, deterministic release, ownership unaffected — see §2.13, §4.7).

Approaching the Beginning Boundary without reaching it is ordinary in-bounds
scrolling, not elastic interaction — see §4.4: it hands viewport ownership to
the user, same as scrolling anywhere else in history. Only actually reaching
and releasing past the boundary triggers the elastic snap to the first
message; when the first message is also the last message (a single-message
conversation) the two boundaries are indistinguishable, as before.

---

# 2.13 CANONICAL RECOVERY

When elastic interaction ends:

The viewport always resolves toward its canonical resting alignment.

Recovery must be:

* Deterministic
* Predictable
* Interruptible
* Consistent

Recovery should never depend upon:

* Gesture velocity
* Temporary displacement distance
* Frame timing
* Accumulated offsets

The viewport always knows where home is.

Recovery simply returns it there.

---

# 2.14 VIEWPORT INVARIANTS

The following statements are always true.

✓ The viewport has one canonical resting alignment while following the live conversation.

✓ The Active Reading Area remains visually stable.

✓ Elastic displacement never changes conversation state.

✓ Elastic displacement never changes scroll ownership.

✓ Temporary displacement never establishes a new resting position.

✓ Historical navigation never occurs accidentally.

✓ Canonical recovery always returns to the layout-defined resting alignment.

✓ The user always knows where the live conversation exists.

✓ The viewport prioritizes continuity over motion.

✓ The viewport reinforces spatial memory through consistent positioning.

---

# 2.15 SUCCESS CRITERIA

The Viewport System is successful when:

Users unconsciously expect where conversation will appear.

Users rarely reposition the viewport during active conversation.

Temporary interactions always resolve predictably.

The viewport feels stable regardless of conversation length.

The interface develops a consistent spatial rhythm.

The viewport quietly disappears from the user's awareness.

The user's attention remains entirely on the conversation.

---

# 3. MOTION SYSTEM

## Purpose

The Motion System defines how the conversation moves through space.

Motion exists to communicate changes in interaction state.

It does not exist to entertain, decorate, or demonstrate technical capability.

Every movement within the conversation must reinforce the user's mental model of the interaction.

Motion is behavior.

Animation is presentation.

The Motion System defines behavior.

The Presentation System determines how that behavior is rendered.

---

# 3.1 MOTION RESPONSIBILITY

The Motion System owns:

* Movement
* Recovery
* Continuity
* Transition
* Displacement
* Interruption

The Motion System does not own:

* Conversation state
* Viewport ownership
* Gesture recognition
* Rendering
* Animation curves
* Timing functions

Those responsibilities belong to other systems.

---

# 3.2 MOTION PHILOSOPHY

Motion should never become the user's focus.

The purpose of motion is to preserve understanding.

If movement attracts attention to itself, it has failed.

The ideal motion is often the one the user barely notices.

Users should understand movement intuitively rather than observe it consciously.

---

# 3.3 MOTION PRINCIPLES

Every implementation must preserve these principles.

---

## Principle 1

### Motion Explains State

Motion communicates changes that have already occurred.

Motion never creates new meaning.

The user should understand *why* something moved before noticing *how* it moved.

---

## Principle 2

### Motion Preserves Thought

Motion should maintain the user's train of thought.

It should never interrupt reading.

It should never compete with content.

Movement exists to reduce cognitive effort, not increase it.

---

## Principle 3

### Motion Is Predictable

The same interaction should always produce the same movement.

Users should quickly develop unconscious expectations.

Predictability builds trust.

Surprise erodes it.

---

## Principle 4

### Motion Is Continuous

Conversation is continuous.

Motion should reflect that continuity.

Transitions should feel like the natural progression of a single interaction rather than a sequence of unrelated events.

---

## Principle 5

### Motion Respects Spatial Memory

Motion should reinforce the user's understanding of where things belong.

Objects should never appear disconnected from their previous location.

The interface should never "teleport" information.

---

## Principle 6

### Motion Is Intentional

Nothing moves without reason.

Every movement should communicate one of:

* Progress
* Recovery
* Navigation
* Structural adaptation

If movement communicates none of these, it should not exist.

---

## Principle 7

### Motion Never Redefines State

Motion expresses state.

It does not create it.

Conversation state always exists independently of motion.

Viewport state always exists independently of motion.

Motion merely communicates those states.

---

# 3.4 MOTION CATEGORIES

All movement belongs to exactly one category.

No movement may belong to multiple categories simultaneously.

---

## Progress Motion

Represents conversation advancing.

Examples:

* Streaming responses
* New messages entering the conversation
* Continuing generation

Progress Motion communicates that conversation is evolving.

---

## Recovery Motion

Returns the interface to its canonical state.

Examples:

* Elastic boundary recovery
* Returning to the live conversation
* Restoring canonical alignment

Recovery Motion always terminates at a known resting state.

Recovery never invents a new resting state.

---

## Structural Motion

Communicates changes in interface structure.

Examples:

* Keyboard appearance
* Keyboard dismissal
* Composer expansion
* Device rotation
* Safe area changes

Structural Motion preserves reading continuity during environmental change.

---

## Navigational Motion

Represents intentional movement through conversation history.

Examples:

* Browsing previous messages
* Returning to the live conversation
* Jumping between conversation regions

Navigational Motion reflects user intent.

It is never initiated without explicit user action.

---

## Transitional Motion

Communicates changes between interaction states.

Examples:

* Thinking → Streaming
* Streaming → Completed
* Idle → Active

Transitional Motion should be minimal.

The change of state is more important than the movement itself.

---

# 3.5 MOTION CONTINUITY

The conversation should feel like one continuous interaction.

Motion should reinforce continuity.

Multiple simultaneous movements should appear coordinated.

Independent systems should never appear to compete for visual attention.

If several systems move simultaneously, the user should perceive one coherent interaction.

---

# 3.6 CANONICAL RECOVERY

Some interactions temporarily displace the interface.

Examples include:

* Elastic boundary interaction
* Temporary presentation displacement
* Transitional structural adjustments

These interactions are temporary.

When temporary interaction concludes, recovery begins.

Recovery always returns the affected system to its canonical resting state.

Recovery never creates new resting positions.

Recovery never depends on accumulated offsets.

Recovery never depends on gesture history.

The destination already exists.

Recovery simply returns the system there.

---

# 3.7 ELASTIC MOTION

Elastic motion acknowledges user intent while preserving system state.

Elastic motion may temporarily displace presentation.

Elastic motion never changes:

* Conversation state
* Viewport ownership
* Reading state
* Navigation state

Elastic motion exists only while interaction is active.

Upon completion:

Presentation returns to the canonical resting alignment.

The underlying system remains unchanged throughout.

Elastic motion is expressive.

It is not navigational.

---

# 3.8 INTERRUPTIBILITY

All motion should be interruptible.

User intent always takes precedence over ongoing movement.

If a new interaction begins while motion is occurring:

The current motion should yield naturally.

The interface should never appear to resist the user.

Motion serves interaction.

Interaction never serves motion.

---

# 3.9 MOTION INVARIANTS

The following statements are always true.

✓ Motion communicates existing state.

✓ Motion never creates state.

✓ Every movement has a single purpose.

✓ Every movement belongs to exactly one motion category.

✓ Recovery always returns to a canonical resting state.

✓ Temporary displacement never becomes permanent.

✓ Motion reinforces spatial memory.

✓ Motion remains predictable.

✓ User intent always overrides ongoing movement.

✓ Multiple systems present coordinated movement rather than competing movement.

---

# 3.10 ENGINEERING GUIDANCE

When implementing motion:

Begin by identifying the behavioral state transition.

Only after the behavioral transition is understood should presentation be considered.

Never implement motion first and infer behavior afterward.

Behavior defines motion.

Presentation expresses motion.

This ordering is mandatory.

---

# 3.11 COMMON FAILURE MODES

The following architectural failures should be treated as defects.

• Motion creates new interface state.

• Recovery depends upon accumulated offsets.

• Multiple systems compete to control movement.

• Motion exists without communicating meaning.

• Motion interrupts reading.

• Elastic displacement changes viewport ownership.

• Recovery establishes arbitrary resting positions.

• Motion behaves differently for equivalent interactions.

• Presentation layers redefine behavior.

• Animation timing alters interaction semantics.

If any of these conditions occur, the architecture should be reconsidered before additional implementation work proceeds.

---

# 3.12 SUCCESS CRITERIA

The Motion System is successful when:

Movement feels inevitable rather than designed.

Users predict motion before it occurs.

Motion quietly reinforces understanding.

Recovery always feels natural.

Independent systems move as one coordinated interaction.

Users remember the conversation, not the animation.

The interface preserves thought by making movement disappear into the experience.

---

# 4. SCROLL OWNERSHIP SYSTEM

## Purpose

The Scroll Ownership System defines who has authority over viewport movement.

The system exists to preserve the relationship between user intent and automated behavior.

A conversational interface must know when it is responsible for guiding the user and when it must yield control.

The fundamental principle:

**The system may assist the user. It may never compete with the user.**

---

# 4.1 SCROLL OWNERSHIP RESPONSIBILITY

The Scroll Ownership System owns:

* Authority over viewport movement
* Transition between automated and user-controlled movement
* Following behavior during active conversation
* Detachment from live conversation
* Returning authority to the system

The Scroll Ownership System does not own:

* Message creation
* Viewport rendering
* Motion presentation
* Conversation lifecycle
* User input

Those responsibilities belong to other systems.

---

# 4.2 OWNERSHIP MODEL

The viewport always has exactly one owner.

Ownership may belong to:

1. System
2. User

No other ownership state exists.

Ownership is never shared.

Ambiguous ownership creates unpredictable behavior.

---

# 4.3 SYSTEM OWNERSHIP

System ownership represents the default conversational state.

The system owns the viewport when:

* The user is participating in the active conversation
* New messages are being introduced
* Assistant responses are streaming
* The conversation is progressing naturally

While the system owns the viewport:

* The active exchange remains visible
* The viewport follows conversation progress
* New content is presented naturally
* The user does not need to manually reposition the conversation

System ownership represents alignment with the live conversation.

---

# 4.4 USER OWNERSHIP

User ownership begins when the user intentionally chooses to navigate away from the live conversation.

Examples:

* Reviewing previous messages
* Reading historical context
* Exploring earlier parts of the conversation

Once user ownership begins:

* The system stops automatic movement
* Incoming content does not reposition the viewport
* Streaming continues independently
* The user's reading position is preserved

The system must respect the user's decision to browse.

---

# 4.5 OWNERSHIP TRANSITION

Ownership transitions must be intentional.

The system should never unexpectedly take control from the user.

The user should never unexpectedly lose control.

The transition from System Ownership to User Ownership occurs when:

The user demonstrates intent to navigate independently.

The transition from User Ownership to System Ownership occurs when:

* The user explicitly returns to the live conversation
* The user reaches the live conversation naturally
* The user selects a return-to-live action

Ownership changes should be clear and predictable.

---

# 4.6 AUTOMATIC MOVEMENT RULE

Automatic movement is only permitted while the system owns the viewport.

The system must not:

* Pull the user away from history
* Override manual exploration
* Interrupt reading
* Reposition content without meaningful state change

Automatic movement without ownership is a violation of this architecture.

---

# 4.7 ELASTIC INTERACTION AND OWNERSHIP

Elastic displacement does not change ownership.

A temporary pull beyond a viewport boundary is not navigation.

It does not indicate that the user wants to browse history.

Examples:

* Pulling beyond the beginning boundary
* Pulling beyond the live boundary

These interactions remain system-owned.

They are temporary viewport displacement, not ownership transfer.

---

# 4.8 RETURN TO LIVE CONVERSATION

Returning to the live conversation is a transfer of authority.

The transition follows:

User Ownership

↓

Return Intent

↓

Viewport Recovery

↓

System Ownership

The return process should:

* Restore canonical viewport alignment
* Reconnect the user with the active exchange
* Remove historical detachment
* Restore automatic conversation following

The user should clearly understand that the live conversation has resumed.

---

# 4.9 STREAMING DURING USER OWNERSHIP

The conversation may continue while the user owns the viewport.

Generation and viewport ownership are independent systems.

While the user is browsing history:

* Responses may continue generating
* Messages may continue arriving
* The viewport remains unchanged

The system should never force the user to follow generation.

The user decides when to return.

---

# 4.10 OWNERSHIP INVARIANTS

The following statements are always true.

✓ The viewport has exactly one owner.

✓ Ownership is either System or User.

✓ User intent always overrides automated movement.

✓ System movement only occurs during System Ownership.

✓ User browsing is never interrupted.

✓ Elastic displacement never changes ownership.

✓ Conversation generation continues independently of ownership.

✓ Returning to live conversation restores System Ownership.

✓ Ownership transitions are predictable.

✓ The system never fights the user.

---

# 4.11 ENGINEERING GUIDANCE

When implementing viewport movement:

First determine ownership.

Then determine allowed movement.

Never determine movement first and infer ownership afterward.

Ownership must be established before behavior is executed.

A system that does not know who owns the viewport cannot produce predictable behavior.

---

# 4.12 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Automatic scrolling while the user is reading history.

• Streaming forcibly moving the viewport.

• Elastic gestures triggering historical navigation.

• Multiple systems attempting to control viewport movement.

• Ownership changing without explicit user intent.

• The system reclaiming control without the user returning.

• User actions being interpreted as passive gestures.

• Generation state and viewport state becoming coupled.

• Return-to-live behavior creating a new resting position.

---

# 4.13 SUCCESS CRITERIA

The Scroll Ownership System is successful when:

Users always feel in control.

The system knows when to guide and when to stop.

Active conversations feel effortless.

Historical exploration feels safe.

Returning to the live conversation feels natural.

The user never wonders why the viewport moved.

The interface feels intelligent because it understands intent.

---

# 5. READING FLOW SYSTEM

## Purpose

The Reading Flow System defines how the user experiences the progression of conversation.

A conversational interface is not successful because it displays messages correctly.

It is successful because the user can maintain understanding.

The purpose of the Reading Flow System is to preserve:

* Attention
* Context
* Continuity
* Comprehension
* Conversational rhythm

The system exists to ensure the user always understands:

* What was said
* What is being answered
* What is happening now
* What they should consider next

---

# 5.1 READING FLOW RESPONSIBILITY

The Reading Flow System owns:

* Visual attention priority
* Current exchange emphasis
* Context preservation
* Conversational rhythm
* Cognitive continuity

The Reading Flow System does not own:

* Viewport movement
* Message generation
* Layout rendering
* Motion behavior
* User input

Those responsibilities belong to other systems.

---

# 5.2 CONVERSATION IS NOT A FEED

A conversation is not a chronological content stream.

Feeds optimize for discovery.

Conversations optimize for understanding.

The interface should not treat every message as equally important.

The current exchange has greater importance than historical context.

The user's attention should naturally prioritize:

1. Current user intent
2. Current assistant response
3. Immediate conversational context
4. Historical information

---

# 5.3 ACTIVE EXCHANGE PRIORITY

Every conversation has an active exchange.

The active exchange consists of:

* The user's current message
* The assistant's current response
* The immediate relationship between them

The interface should naturally emphasize the active exchange.

Historical messages should remain available without competing for attention.

The user should never need to visually search for where the conversation currently is.

---

# 5.4 READING RHYTHM

Conversation develops a rhythm.

Each interaction follows a recognizable pattern:

User expresses intent.

Assistant responds.

User evaluates.

Conversation continues.

The interface should reinforce this rhythm through consistent spatial behavior.

Every exchange should feel like part of the same continuous interaction.

---

# 5.5 CONTEXT PRESERVATION

The interface must preserve enough context for comprehension.

The user should understand the current response without requiring unnecessary navigation.

Context should remain available.

Context should not dominate.

The system must balance:

* Current focus
* Recent history
* Long-term conversation memory

---

# 5.6 CONTEXT DECAY

Historical content naturally decreases in visual priority over time.

This is not deletion.

This is attention management.

As conversation progresses:

* New content becomes primary
* Recent content becomes secondary
* Older content becomes reference material

The interface should allow context to leave attention without making it feel lost.

---

# 5.7 READING STABILITY

Reading should not be interrupted by unrelated system behavior.

The following events should preserve comprehension:

* Streaming updates
* Keyboard changes
* Layout adjustments
* Response completion
* System transitions

The user should never lose their place unexpectedly.

---

# 5.8 STREAMING READING FLOW

Streaming responses create a unique reading state.

The user is not reading a completed document.

They are observing a response form.

During streaming:

* New information arrives continuously
* The user's attention follows the active response
* Layout changes should remain predictable

Streaming should feel like participating in a conversation.

It should not feel like watching content load.

---

# 5.9 CONVERSATIONAL MOMENTUM

Conversation should maintain forward momentum.

The interface should make the next action obvious.

The user should naturally understand:

* Where to read
* Where to respond
* Where the conversation continues

Momentum is created through consistency, not speed.

---

# 5.10 ATTENTION PRESERVATION

The interface should avoid unnecessary cognitive interruptions.

Avoid behaviors that require the user to:

* Reorient after movement
* Search for the active exchange
* Determine why the viewport changed
* Recover lost context

Every unnecessary interaction cost reduces conversational quality.

---

# 5.11 READING FLOW INVARIANTS

The following statements are always true.

✓ The current exchange receives the highest visual priority.

✓ Historical messages remain accessible but secondary.

✓ The user should never lose their place unexpectedly.

✓ Conversation progression should feel continuous.

✓ Streaming should preserve comprehension.

✓ Context should be available without overwhelming attention.

✓ The interface should optimize for understanding, not message visibility.

✓ The user should rarely need to manually manage the conversation view.

✓ Reading should remain stable during system changes.

✓ The interface should support thought, not interrupt it.

---

# 5.12 ENGINEERING GUIDANCE

When making decisions that affect conversation presentation:

Ask:

"Does this help the user understand the conversation?"

Do not ask:

"Does this display more information?"

More information does not always create more understanding.

The system should optimize for cognitive clarity.

---

# 5.13 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Treating conversation as a feed.

• Giving historical messages equal priority with the active exchange.

• Allowing streaming to disrupt reading.

• Moving the viewport without preserving context.

• Requiring users to manually manage conversation position.

• Prioritizing visual effects over comprehension.

• Making the user search for the current exchange.

• Showing too much context at the expense of focus.

• Allowing interface behavior to interrupt thought.

---

# 5.14 SUCCESS CRITERIA

The Reading Flow System is successful when:

Users always understand where they are.

The active exchange is immediately obvious.

Conversation feels continuous.

History feels available but unobtrusive.

Streaming feels natural.

The interface reduces cognitive effort.

The user focuses on the conversation rather than managing the conversation.

---

# 6. KEYBOARD COORDINATION SYSTEM

## Purpose

The Keyboard Coordination System defines how the conversation adapts when the user's primary input environment changes.

The keyboard is not an external overlay.

It is part of the conversational environment.

When the keyboard appears, the conversation should adapt while preserving:

* Reading continuity
* User intent
* Spatial memory
* Input focus
* Conversational momentum

The keyboard should never feel like it interrupts the conversation.

It should feel like the conversation naturally makes room for input.

---

# 6.1 KEYBOARD COORDINATION RESPONSIBILITY

The Keyboard Coordination System owns:

* Keyboard state awareness
* Input environment transitions
* Relationship between composer and viewport
* Focus continuity
* Preservation of conversational context

The Keyboard Coordination System does not own:

* Message creation
* Conversation lifecycle
* Viewport ownership
* Motion presentation
* Text rendering

Those responsibilities belong to other systems.

---

# 6.2 KEYBOARD AS ENVIRONMENTAL STATE

The keyboard represents a change in available interaction space.

It is not:

* A modal interruption
* A separate interface layer
* A temporary screen replacement

It is an environmental condition that the conversation adapts around.

The conversation remains the primary experience.

The keyboard is simply the current method of expressing intent.

---

# 6.3 INPUT INTENT PRESERVATION

When the user activates input:

The system should preserve the user's conversational intent.

The user has made a decision:

"I want to continue this conversation."

The interface should support that decision immediately.

The transition into input should preserve:

* Current conversational context
* Active exchange awareness
* Input focus
* Reading orientation

The user should not need to manually prepare the interface before responding.

---

# 6.4 VIEWPORT RELATIONSHIP

The keyboard and viewport are coordinated systems.

The keyboard may influence available space.

The keyboard may not redefine conversation state.

When the keyboard appears:

* The active exchange remains understandable
* The user's draft remains connected to the conversation
* The viewport maintains continuity

The keyboard should never cause the user to lose their conversational position.

---

# 6.5 COMPOSER RELATIONSHIP

The composer is the bridge between user intent and conversation.

The keyboard supports the composer.

The composer supports the conversation.

The relationship is:

User Intent

↓

Composer

↓

Keyboard

↓

Conversation

The keyboard should never become the primary focus of the experience.

The conversation remains primary.

---

# 6.6 KEYBOARD APPEARANCE

When the keyboard appears:

The system should establish a stable input environment.

The user should immediately understand:

* Where they are typing
* What they are responding to
* How their message relates to the conversation

Keyboard appearance should not create uncertainty.

---

# 6.7 KEYBOARD DISMISSAL

Keyboard dismissal represents the user leaving the input state.

The system should preserve conversational continuity.

Dismissal should not:

* Reset conversation position
* Unexpectedly reposition content
* Change ownership without intent
* Remove context

The user should return naturally to the conversation.

---

# 6.8 FOCUS CONTINUITY

Input focus is a continuation of intent.

When focus changes:

The system should preserve the user's mental state.

Examples:

* Returning from another interaction
* Reopening input
* Editing a draft
* Continuing a response

Focus transitions should feel like returning to an existing thought.

---

# 6.9 KEYBOARD AND SCROLL OWNERSHIP

Keyboard appearance does not automatically determine viewport ownership.

The following are independent:

* Input state
* Keyboard state
* Viewport ownership

A user entering text does not necessarily mean the system owns the viewport.

Ownership remains governed by the Scroll Ownership System.

---

# 6.10 KEYBOARD AND MOTION

Keyboard transitions may require motion.

Any motion caused by keyboard changes must follow the Motion System.

Keyboard-related movement must be:

* Predictable
* Necessary
* Context-preserving
* Minimal

The keyboard should never cause arbitrary movement.

---

# 6.11 KEYBOARD INVARIANTS

The following statements are always true.

✓ The keyboard is part of the conversational environment.

✓ Keyboard appearance never changes conversation state.

✓ Keyboard appearance never automatically changes viewport ownership.

✓ Input intent is preserved through keyboard transitions.

✓ The user should never lose conversational context when typing.

✓ Keyboard-related motion follows the Motion System.

✓ The composer and viewport remain coordinated.

✓ Dismissing the keyboard should not disrupt reading flow.

✓ The conversation remains primary.

✓ The keyboard serves intent; it does not define the experience.

---

# 6.12 ENGINEERING GUIDANCE

When implementing keyboard behavior:

Do not begin with:

"How do we move the content when the keyboard appears?"

Begin with:

"What is the user trying to accomplish?"

Then determine:

* What state the conversation is in
* Who owns the viewport
* What information must remain visible
* What movement is actually necessary

The keyboard should trigger adaptation, not reaction.

---

# 6.13 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Keyboard appearance unexpectedly changes conversation position.

• Input focus causes loss of context.

• Keyboard state controls viewport ownership.

• User intent is interrupted by automatic repositioning.

• Keyboard transitions compete with conversation content.

• Composer behavior is disconnected from viewport behavior.

• Dismissing the keyboard creates unexpected movement.

• The keyboard is treated as a separate screen state.

• Input interaction causes historical navigation.

---

# 6.14 SUCCESS CRITERIA

The Keyboard Coordination System is successful when:

Typing feels like a natural continuation of conversation.

The keyboard appears without disrupting thought.

The user's position remains understandable.

Input focus feels immediate.

The composer feels connected to the conversation.

The user never thinks about keyboard management.

The keyboard disappears into the experience as naturally as it appears.

---

# 7. COMPOSER SYSTEM

## Purpose

The Composer System defines how user intent becomes a conversational action.

The composer is the bridge between human thought and conversation state.

It is not a text field.

It is not a control.

It is not a separate interface surface.

The composer is the user's primary mechanism for expressing intent.

The Composer System exists to preserve:

* Intent
* Focus
* Continuity
* Control
* Expression

---

# 7.1 COMPOSER RESPONSIBILITY

The Composer System owns:

* User input preparation
* Draft state
* Input intent
* Submission intent
* Transition from input to conversation

The Composer System does not own:

* Conversation generation
* Assistant responses
* Viewport movement
* Keyboard behavior
* Message rendering

Those responsibilities belong to other systems.

---

# 7.2 COMPOSER PHILOSOPHY

The composer should feel like a continuation of thought.

The user should not feel like they are entering a separate application mode.

The transition should be:

Thinking

↓

Expressing

↓

Conversing

The composer exists to reduce friction between those states.

---

# 7.3 INTENT FIRST MODEL

The fundamental unit of the composer is intent.

Text is one expression of intent.

It is not the intent itself.

Future input methods may include:

* Text
* Voice
* Images
* Files
* Structured actions
* Other modalities

All input methods should enter the conversation through the same intent model.

The architecture should not privilege one input modality over another.

---

# 7.4 DRAFT STATE

The composer maintains a temporary user expression before submission.

A draft represents:

"I am forming a thought."

A draft is not yet conversation state.

The system must preserve the distinction between:

Draft

and

Submitted Message

A draft should remain independent until the user explicitly commits it.

---

# 7.5 DRAFT PRESERVATION

Draft content should be resilient.

The system should preserve user effort during:

* Keyboard changes
* Focus changes
* Temporary interruptions
* Navigation events
* Environmental changes

The user should never lose an unfinished thought without explicit action.

---

# 7.6 SUBMISSION INTENT

Submission represents a deliberate transition:

Draft

↓

User Intent

↓

Conversation State

The system should clearly understand when the user has committed their message.

Submission should not be confused with:

* Typing
* Focus changes
* Keyboard dismissal
* Temporary interaction

A message enters the conversation only after intentional submission.

---

# 7.7 COMPOSER AND VIEWPORT RELATIONSHIP

The composer and viewport are coordinated systems.

The composer influences available interaction space.

It does not control the conversation position.

When the composer changes:

The Viewport System determines how the conversation should respond.

The Composer System should never independently reposition the conversation.

---

# 7.8 COMPOSER EXPANSION

Composer size may change as user intent grows.

Expansion should preserve:

* Input focus
* Draft continuity
* Conversation awareness

Growth should feel like the interface adapting to the user's thought.

It should not feel like the interface pushing the conversation away.

---

# 7.9 COMPOSER AND KEYBOARD RELATIONSHIP

The composer requests input.

The keyboard provides the input environment.

Neither system owns the other.

The relationship is:

User Intent

↓

Composer

↓

Keyboard Environment

↓

Conversation

The keyboard should support expression.

The composer should support intent.

---

# 7.10 COMPOSER SUBMISSION FLOW

A successful submission follows:

User forms intent

↓

User expresses intent

↓

User commits intent

↓

Conversation receives intent

↓

Viewport adapts according to ownership rules

↓

Conversation lifecycle begins

Each stage has a separate responsibility.

No stage should skip another.

---

# 7.11 COMPOSER INTERRUPTION

Users may abandon or interrupt expression.

The system should support:

* Editing
* Clearing
* Revising
* Pausing
* Continuing

Interruption should preserve user control.

The system should never force completion of an unfinished thought.

---

# 7.12 COMPOSER AND MULTIMODAL INPUT

The Composer System must support future expansion.

Text is only one input mechanism.

Future inputs should follow the same architecture:

Intent

↓

Composer

↓

Conversation

The architecture should not require separate input pipelines for:

* Voice
* Images
* Attachments
* Structured commands
* Agent actions

---

# 7.13 COMPOSER INVARIANTS

The following statements are always true.

✓ The composer represents user intent.

✓ A draft is not conversation state.

✓ Submission requires user intent.

✓ The composer does not own viewport movement.

✓ The composer does not own conversation lifecycle.

✓ User effort is preserved.

✓ Input modalities share a common intent model.

✓ The keyboard supports the composer but does not define it.

✓ The conversation remains the destination of user expression.

✓ The user always controls when thought becomes conversation.

---

# 7.14 ENGINEERING GUIDANCE

When implementing composer behavior:

Do not begin with:

"How should this input component behave?"

Begin with:

"What is the user trying to accomplish?"

The implementation should serve the intent model.

Avoid creating separate architectural paths for different input types.

New input methods should extend the composer system, not bypass it.

---

# 7.15 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Treating the composer as only a text field.

• Losing drafts during environmental changes.

• Allowing typing state to modify conversation state.

• Allowing composer changes to directly control viewport movement.

• Creating separate systems for different input modalities.

• Submitting content without explicit user intent.

• Making the composer feel disconnected from the conversation.

• Allowing input mechanics to dominate the experience.

---

# 7.16 SUCCESS CRITERIA

The Composer System is successful when:

Users can express thoughts naturally.

Drafts feel safe and persistent.

Submission feels intentional.

Input feels connected to conversation.

Future modalities integrate naturally.

The user never thinks about the composer as a separate system.

The composer disappears and the user's intent remains.

---

# 8. CONVERSATION LIFECYCLE SYSTEM

## Purpose

The Conversation Lifecycle System defines how a conversation progresses through states over time.

A conversation is not a static collection of messages.

A conversation is an evolving interaction between user intent and system response.

The Conversation Lifecycle System is responsible for defining:

* State transitions
* Message progression
* Response generation
* Completion
* Interruption
* Recovery

The system exists to ensure every conversation state is predictable, understandable, and recoverable.

---

# 8.1 CONVERSATION LIFECYCLE RESPONSIBILITY

The Conversation Lifecycle System owns:

* Conversation state
* Exchange progression
* Message lifecycle
* Response lifecycle
* Generation state
* Completion state

The Conversation Lifecycle System does not own:

* Viewport position
* Scroll ownership
* Motion behavior
* Keyboard behavior
* Visual presentation

Those responsibilities belong to other systems.

---

# 8.2 CONVERSATION AS STATE TRANSITION

A conversation should be understood as a sequence of state transitions.

The fundamental lifecycle is:

User Intent

↓

User Expression

↓

Submission

↓

Processing

↓

Response Generation

↓

Completion

↓

Continuation

Each transition represents a meaningful change in conversational state.

---

# 8.3 CORE CONVERSATION STATES

The conversation operates through defined states.

The primary states are:

---

## Idle State

The conversation is waiting for user intent.

Characteristics:

* No active user submission
* No active response generation
* The system is available for continuation

The Idle state represents readiness.

---

## Composing State

The user is actively forming a thought.

Characteristics:

* User intent exists
* Draft may be incomplete
* Conversation state has not advanced

The Composing state belongs to the user.

The system should preserve user control.

---

## Submitted State

The user has committed an intent.

Characteristics:

* User message is accepted
* Conversation sequence advances
* Processing may begin

Submission represents a clear transition from user-controlled expression into system processing.

---

## Processing State

The system has accepted the request and is determining a response.

Characteristics:

* The conversation is active
* Response generation has not yet completed
* The user may observe progress

Processing represents system participation.

---

## Streaming State

The response is actively being generated.

Characteristics:

* Partial response exists
* New information continues arriving
* Conversation is actively evolving

Streaming should preserve conversational continuity.

---

## Completed State

The response has finished.

Characteristics:

* Exchange is complete
* Conversation is stable
* The user may continue

Completion does not end the conversation.

It prepares the next interaction.

---

## Interrupted State

An active process has been stopped.

Examples:

* User cancels generation
* Network interruption
* System interruption

The conversation must remain understandable.

An interruption is a state transition, not a failure of the entire conversation.

---

## Recovery State

The system is restoring a valid conversational state.

Examples:

* Retrying generation
* Restoring interrupted state
* Recovering from temporary failure

Recovery must return to a known state.

---

# 8.4 STATE OWNERSHIP

Each lifecycle state has an owner.

User-owned states:

* Composing
* Editing
* Submission intent

System-owned states:

* Processing
* Streaming
* Completion
* Recovery

Ownership determines who controls progression.

The system must not advance user-owned states without intent.

The user must not manually manipulate system-owned states.

---

# 8.5 STATE TRANSITION RULES

All transitions must be:

* Explicit
* Predictable
* Recoverable

A state should never change simply because presentation changes.

Examples:

Keyboard appearance does not change conversation state.

Viewport movement does not change conversation state.

Animation does not change conversation state.

Only meaningful conversational events change lifecycle state.

---

# 8.6 MESSAGE LIFECYCLE

Each message follows its own lifecycle.

User message:

Draft

↓

Committed

↓

Added to conversation

↓

Complete

Assistant message:

Created

↓

Processing

↓

Streaming

↓

Complete

↓

Available for continuation

The message lifecycle and conversation lifecycle are related but independent.

---

# 8.7 CONVERSATION CONTINUITY

Every lifecycle transition should preserve continuity.

The user should understand:

* What happened
* What is happening
* What happens next

The interface should never create ambiguous states.

Examples of ambiguity:

* Is the response still generating?
* Was the message sent?
* Did the system fail?
* Did the conversation stop?

Every state must communicate itself naturally.

---

# 8.8 MULTIPLE EXCHANGES

A conversation contains many exchanges.

Each exchange should remain independent while contributing to the larger conversation.

The architecture should support:

* Multiple user messages
* Multiple assistant responses
* Long conversations
* Interrupted exchanges
* Revisions

A single exchange failure should not compromise the entire conversation.

---

# 8.9 LIFECYCLE AND VIEWPORT RELATIONSHIP

Conversation lifecycle changes may influence viewport behavior.

They do not directly control it.

The relationship is:

Conversation State

↓

Viewport Decision

↓

Motion Decision

↓

Presentation

The conversation communicates what changed.

The viewport determines what should be visible.

Motion determines how the change is expressed.

---

# 8.10 LIFECYCLE INVARIANTS

The following statements are always true.

✓ Conversation state changes only through meaningful events.

✓ Presentation changes never modify conversation state.

✓ User-owned states require user intent.

✓ System-owned states progress automatically.

✓ Streaming is a valid conversational state.

✓ Interrupted states remain recoverable.

✓ Every state has a clear owner.

✓ Every transition has a known destination.

✓ The user always understands the current state.

✓ Conversation continuity is preserved across transitions.

---

# 8.11 ENGINEERING GUIDANCE

When implementing conversation behavior:

Start with the state machine.

Do not start with the interface.

The interface should be a representation of conversation state.

Never allow UI behavior to become the source of truth.

The conversation model must exist independently from rendering.

---

# 8.12 COMMON FAILURE MODES

The following conditions represent architectural failures:

• UI state becomes the conversation state.

• Streaming behavior bypasses lifecycle rules.

• Messages appear before entering a valid state.

• User intent is assumed instead of confirmed.

• Interrupted conversations become unrecoverable.

• Multiple systems modify lifecycle state.

• Presentation changes trigger state transitions.

• Conversation state and viewport state become coupled.

• The system cannot explain what state the conversation is currently in.

---

# 8.13 SUCCESS CRITERIA

The Conversation Lifecycle System is successful when:

Every interaction has a clear beginning, middle, and end.

Users understand what the system is doing.

Responses feel continuous and intentional.

Interruptions recover gracefully.

New capabilities can enter the lifecycle without creating exceptions.

The conversation feels alive without feeling unpredictable.

---

# 9. STREAMING SYSTEM

## Purpose

The Streaming System defines how dynamically generated responses enter the conversation over time.

A streaming response is not a completed message being progressively rendered.

A streaming response is an active conversational state.

The system exists to preserve:

* Continuity
* Understanding
* Stability
* User awareness
* Reading flow

while new information is arriving.

---

# 9.1 STREAMING RESPONSIBILITY

The Streaming System owns:

* Response generation state
* Partial response lifecycle
* Incremental content arrival
* Streaming completion
* Streaming interruption

The Streaming System does not own:

* Viewport movement
* Scroll ownership
* Motion behavior
* Keyboard behavior
* Conversation presentation

Those responsibilities belong to other systems.

---

# 9.2 STREAMING PHILOSOPHY

Streaming exists to communicate progress.

It should make the user feel:

"The system is thinking and responding."

It should not make the user feel:

"The interface is constantly changing."

The user's attention should remain on the meaning of the response.

Not on the mechanics of generation.

---

# 9.3 STREAMING AS A CONVERSATIONAL STATE

Streaming is an active state within the Conversation Lifecycle.

The transition is:

Processing

↓

Streaming

↓

Completed

Streaming represents:

* The assistant has begun responding
* The response is incomplete
* Additional information may arrive

The response is not unstable.

It is simply unfinished.

---

# 9.4 PARTIAL RESPONSE MODEL

A streaming response exists as a valid conversational object before completion.

The system must treat partial content as meaningful.

Partial responses may contain:

* Beginning of explanation
* Intermediate reasoning
* Emerging structure

The interface should preserve continuity as the response develops.

---

# 9.5 STREAMING AND VIEWPORT RELATIONSHIP

Streaming and viewport behavior are independent systems.

Streaming does not automatically determine viewport movement.

The relationship is:

Streaming State

↓

Viewport System Evaluates Context

↓

Scroll Ownership Determines Authority

↓

Motion System Determines Expression

The arrival of new content does not guarantee that the viewport should move.

---

# 9.6 STREAMING DURING SYSTEM OWNERSHIP

When the system owns the viewport:

Streaming should naturally remain connected to the active exchange.

The user should experience the response as it unfolds.

The viewport may adapt according to established viewport rules.

All movement must follow:

* Viewport invariants
* Motion principles
* Ownership rules

---

# 9.7 STREAMING DURING USER OWNERSHIP

When the user owns the viewport:

Streaming continues independently.

The system must not interrupt intentional browsing.

The user may:

* Read previous context
* Review earlier messages
* Remain detached from the live response

Generation and viewport position are separate concerns.

The system should never force attention back to the response.

---

# 9.8 STREAMING CONTINUITY

A streaming response should feel like one continuous thought.

The user should not perceive:

* Fragmented updates
* Unstable positioning
* Constant repositioning
* Visual noise

Each update should reinforce that the assistant is continuing the same response.

---

# 9.9 STREAMING AND READING FLOW

Streaming must preserve comprehension.

As content arrives:

The user should understand:

* Where the response begins
* Where it is continuing
* Whether it is complete

The system should prioritize:

Understanding

over

Displaying every incremental change.

---

# 9.10 STREAMING INTERRUPTIONS

Streaming may be interrupted.

Examples:

* User cancellation
* Connection failure
* System interruption
* New user intent

An interruption does not invalidate the conversation.

The system should preserve:

* Existing content
* Conversational context
* User understanding

The user should know what happened.

---

# 9.11 STREAMING COMPLETION

Completion represents a transition:

Streaming

↓

Complete

Completion should communicate:

* The response is finished
* The exchange is stable
* The user may continue

Completion should not create unnecessary movement.

The response should naturally settle into the conversation.

---

# 9.12 STREAMING AND MOTION

Streaming-related movement must follow the Motion System.

Streaming should never introduce:

* Decorative movement
* Unnecessary repositioning
* Competing animations

Motion exists only to communicate meaningful change.

---

# 9.13 STREAMING INVARIANTS

The following statements are always true.

✓ Streaming is a conversational state, not a rendering trick.

✓ Partial responses are valid conversational objects.

✓ Streaming does not own the viewport.

✓ Streaming does not override user ownership.

✓ Streaming preserves reading flow.

✓ Streaming interruptions remain recoverable.

✓ Completion does not require dramatic movement.

✓ New content arrival does not automatically require viewport movement.

✓ The user always understands whether a response is active or complete.

✓ Streaming feels like thought unfolding, not content loading.

---

# 9.14 ENGINEERING GUIDANCE

When implementing streaming:

Do not begin with:

"How do we append text?"

Begin with:

"What does the user need to understand while the response is forming?"

The implementation should optimize for conversational continuity.

Streaming is not a text-rendering problem.

It is a state-management problem.

---

# 9.15 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Treating streaming as repeated message updates.

• Allowing streaming to control viewport ownership.

• Forcing the user to follow generation.

• Causing reading position instability.

• Creating visual movement for every token update.

• Making partial responses feel unfinished or broken.

• Losing generated content after interruption.

• Making completion feel like a separate event.

• Coupling generation speed to interaction behavior.

---

# 9.16 SUCCESS CRITERIA

The Streaming System is successful when:

Responses feel alive.

Progress feels natural.

Users understand what is happening.

Reading remains stable.

Interruptions recover gracefully.

The user focuses on the intelligence of the response rather than the mechanics of generation.

Streaming feels like a conversation happening in real time.

---

# 10. HISTORY NAVIGATION SYSTEM

## Purpose

The History Navigation System defines how users explore previous conversation content while maintaining connection to the active conversation.

A conversation has both:

* A present moment
* A historical record

The system must support movement through history without confusing historical exploration with active participation.

The purpose of History Navigation is to preserve:

* Context
* Orientation
* User control
* Returnability
* Continuity

---

# 10.1 HISTORY NAVIGATION RESPONSIBILITY

The History Navigation System owns:

* Historical exploration
* Transition into historical context
* Transition back to live conversation
* Preservation of conversational orientation
* Relationship between past and present

The History Navigation System does not own:

* Conversation state
* Message generation
* Viewport rendering
* Motion behavior
* Keyboard behavior

Those responsibilities belong to other systems.

---

# 10.2 HISTORY PHILOSOPHY

A conversation is both a journey and a destination.

The user may need to:

* Review previous information
* Verify context
* Revisit decisions
* Understand earlier responses

Historical exploration is a valid conversational activity.

The system must support exploration without treating it as a mistake.

---

# 10.3 PRESENT VS HISTORY

The conversation contains two conceptual regions:

## Live Conversation

The current moment.

Characteristics:

* Active exchange
* New responses
* Ongoing interaction
* System participation

---

## Historical Conversation

The recorded past.

Characteristics:

* Reference material
* Previous exchanges
* User exploration

The system must maintain a clear distinction between these regions.

---

# 10.4 ENTERING HISTORY

Entering history occurs when the user intentionally moves away from the live conversation.

This transition represents:

Live Conversation

↓

User Intent

↓

Historical Exploration

The system should recognize this as an intentional change in attention.

Historical exploration should not feel like leaving the conversation.

It should feel like examining it.

---

# 10.5 HISTORY OWNERSHIP

Historical exploration transfers viewport authority to the user.

While exploring history:

* The user controls position
* The system preserves location
* New content does not interrupt reading
* Generation continues independently

The system must respect historical attention.

---

# 10.6 HISTORY AND ACTIVE GENERATION

The conversation may continue while the user explores history.

These systems remain independent:

Conversation Generation

and

Viewport Position

A response may continue forming while the user reads earlier context.

The system must not force synchronization.

---

# 10.7 HISTORICAL CONTEXT

Historical messages remain part of the conversation.

They should preserve:

* Order
* Relationship
* Meaning

The user should be able to reconstruct the conversational path.

History should never feel detached from the present conversation.

---

# 10.8 RETURNING TO LIVE CONVERSATION

Returning to the live conversation represents a change in attention.

The transition is:

Historical Exploration

↓

Return Intent

↓

Viewport Recovery

↓

Live Conversation

The return should restore:

* Current exchange awareness
* System ownership
* Active conversational flow

---

# 10.9 RETURN TO LIVE AS A STATE TRANSITION

Returning to the present is not a visual action.

It is a change in conversational relationship.

The architecture should not define returning to live conversation as:

"Move the viewport to the bottom."

It should define it as:

"Restore connection with the active conversation."

The resulting movement is simply the expression of that state transition.

---

# 10.10 LIVE CONVERSATION REENTRY

When returning to live conversation:

The system should:

* Reconnect the user with current activity
* Restore canonical viewport alignment
* Resume normal ownership behavior
* Preserve conversational understanding

The user should immediately know:

"I am back where the conversation is happening now."

---

# 10.11 HISTORY NAVIGATION AND MOTION

Historical movement follows the Motion System.

Movement through history should be:

* Intentional
* Understandable
* Predictable

The system should avoid unnecessary movement.

The user's exploration should remain primary.

---

# 10.12 HISTORY NAVIGATION AND ELASTIC BOUNDARIES

Reaching the beginning or end of available history does not automatically create navigation behavior.

Boundary interaction and history navigation are separate systems.

A temporary boundary interaction:

* Does not change location
* Does not create historical mode
* Does not change ownership

History navigation requires user intent.

---

# 10.13 HISTORY NAVIGATION INVARIANTS

The following statements are always true.

✓ Historical exploration is a valid user activity.

✓ History is separate from live conversation.

✓ Entering history requires user intent.

✓ Exploring history transfers viewport authority to the user.

✓ New content does not interrupt historical reading.

✓ Conversation generation continues independently.

✓ Returning live is a state transition, not a visual shortcut.

✓ Returning live restores system ownership.

✓ Historical context remains connected to the conversation.

✓ The user never loses the present conversation.

---

# 10.14 ENGINEERING GUIDANCE

When implementing history behavior:

Do not think:

"How do we scroll back?"

Think:

"What relationship does the user currently have with the conversation?"

The key question is not position.

The key question is attention.

The system should always know whether the user is:

* Participating in the present
* Exploring the past

---

# 10.15 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Treating history as a separate document.

• Automatically pulling users back to live conversation.

• Losing the user's historical position.

• Confusing boundary interaction with navigation.

• Making return-to-live purely a visual action.

• Allowing new responses to interrupt historical reading.

• Removing historical context when returning to live.

• Creating multiple ways to define "current conversation."

• Making the user uncertain whether they are in the present or past.

---

# 10.16 SUCCESS CRITERIA

The History Navigation System is successful when:

Users can freely explore previous conversation.

The present conversation remains intact.

Returning to live feels natural.

Historical context feels connected.

The system respects attention.

The user always understands where they are in time.

The conversation feels like one continuous space rather than separate screens.

---

# 11. ACCESSIBILITY CONTRACTS

## Purpose

The Accessibility Contract defines how the Conversation Architecture supports all users and interaction methods.

Accessibility is not a layer added after implementation.

Accessibility is another expression of user intent.

The same architectural principles that support direct interaction should support:

* Assistive technologies
* Alternative input methods
* Different perception needs
* Different physical interaction models

---

# 11.1 ACCESSIBILITY RESPONSIBILITY

The Accessibility System owns:

* Alternative interaction support
* Content interpretation
* Focus behavior
* Adaptability
* User preference accommodation

The Accessibility System does not own:

* Conversation state
* Viewport state
* Motion behavior
* Input lifecycle

Accessibility should integrate with existing systems, not create parallel systems.

---

# 11.2 ACCESSIBILITY PHILOSOPHY

Every user should experience the same conversation.

Accessibility should not create a simplified version of the product.

It should provide alternate ways to access the same underlying experience.

The architecture must preserve:

* Meaning
* Order
* Context
* Control

regardless of interaction method.

---

# 11.3 CONTENT STRUCTURE

Conversation content must remain semantically meaningful.

The system should understand:

* User messages
* Assistant messages
* Streaming responses
* Status changes
* Actions
* Attachments

Presentation should never be the only source of meaning.

---

# 11.4 FOCUS MANAGEMENT

Focus should follow user intent.

The system should preserve:

* Current task
* Current message
* Current interaction state

Focus should never move unexpectedly.

Unexpected focus changes create loss of orientation.

---

# 11.5 DYNAMIC CONTENT

Dynamic conversation updates must communicate clearly.

Examples:

* New messages
* Streaming responses
* Completed generations
* Errors

The user should understand what changed without requiring visual awareness.

---

# 11.6 MOTION ACCESSIBILITY

Motion must respect user preferences.

Reducing motion should reduce presentation effects.

It should not remove:

* Meaning
* State communication
* Orientation

The architecture must separate motion behavior from animation presentation.

---

# 11.7 ACCESSIBILITY INVARIANTS

✓ Meaning is preserved across interaction methods.

✓ Conversation structure remains understandable.

✓ Focus follows user intent.

✓ Dynamic updates remain discoverable.

✓ Accessibility does not create a separate product experience.

✓ User preferences modify presentation, not behavior.

---

# 11.8 COMMON FAILURE MODES

• Accessibility implemented as an afterthought.

• Focus changing without user intent.

• Dynamic updates becoming confusing.

• Meaning depending only on visual presentation.

• Alternate input methods bypassing core architecture.

---

# 11.9 SUCCESS CRITERIA

The Accessibility Contract succeeds when:

Every user can participate naturally.

The conversation remains understandable.

Alternative interaction methods feel native.

Accessibility strengthens the architecture rather than complicating it.

---

# 12. PERFORMANCE CONTRACTS

## Purpose

The Performance Contract defines how the Conversation Architecture maintains consistent behavior as complexity increases.

Performance is not only about speed.

Performance is about preserving the quality of interaction regardless of:

* Conversation length
* Content complexity
* Response duration
* Device capability
* Feature expansion

The user should experience the same conversation quality whether the conversation contains ten messages or thousands.

---

# 12.1 PERFORMANCE RESPONSIBILITY

The Performance System owns:

* Efficiency
* Resource management
* Scalability
* Responsiveness
* Stability under load

The Performance System does not own:

* Conversation behavior
* Viewport rules
* Motion rules
* Ownership rules
* User intent

Performance improvements must preserve architectural behavior.

---

# 12.2 PERFORMANCE PHILOSOPHY

Performance should be invisible.

The user should not notice optimization.

They should only experience:

* Stability
* Responsiveness
* Continuity

A faster system that changes behavior is not an improvement.

---

# 12.3 BEHAVIORAL PRESERVATION

Performance optimizations may improve:

* Speed
* Memory usage
* Rendering efficiency
* Resource consumption

Performance optimizations may never change:

* Conversation state
* Viewport behavior
* Ownership rules
* Motion semantics
* Reading flow

Behavior is the contract.

Performance supports the contract.

---

# 12.4 CONVERSATION SCALE

The architecture must support conversations of increasing size without changing user experience.

As conversations grow:

* Historical content remains accessible
* Current exchange remains prioritized
* Viewport behavior remains predictable
* Ownership rules remain consistent

A longer conversation should feel like the same conversation.

Not a different product.

---

# 12.5 STREAMING PERFORMANCE

Streaming performance must preserve conversational continuity.

Optimizations must not create:

* Visual instability
* Interrupted reading
* Lost response content
* Unpredictable movement

The user should experience one continuous response.

---

# 12.6 STATE PRESERVATION

Performance systems must preserve meaningful state.

The following must remain stable:

* Current conversation state
* User ownership state
* Viewport state
* Draft state
* Active exchange context

Optimization must not reset user context.

---

# 12.7 RESOURCE MANAGEMENT

Resource decisions should prioritize active conversation.

The system should prioritize:

1. Current exchange
2. Immediate context
3. Recent history
4. Older history

This ordering follows the Reading Flow System.

---

# 12.8 PERFORMANCE AND VIEWPORT

Performance optimization must never compromise viewport invariants.

The following must remain true:

* Canonical resting alignment remains stable.
* Ownership remains accurate.
* Reading position remains understandable.
* Recovery behavior remains predictable.

A performance optimization that causes viewport instability is an architectural regression.

---

# 12.9 PERFORMANCE INVARIANTS

✓ Performance improvements preserve behavior.

✓ Large conversations behave like small conversations.

✓ Optimization never changes ownership.

✓ Optimization never changes viewport rules.

✓ Streaming remains stable under load.

✓ User context is preserved.

✓ Resource management follows conversational priority.

✓ Responsiveness supports thought, not interruption.

---

# 12.10 ENGINEERING GUIDANCE

When optimizing:

Do not ask:

"How can we make this render faster?"

Ask:

"How can we preserve the same conversational experience with fewer resources?"

The goal is not simply faster execution.

The goal is identical behavior at greater scale.

---

# 12.11 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Large conversations behave differently than small conversations.

• Optimization changes viewport behavior.

• Performance shortcuts bypass ownership rules.

• Memory management causes context loss.

• Streaming becomes unstable under load.

• Rendering optimization creates visual discontinuity.

• Cached states become sources of truth.

• Performance improvements create interaction inconsistencies.

---

# 12.12 SUCCESS CRITERIA

The Performance Contract succeeds when:

The conversation feels identical at any scale.

Long conversations remain usable.

Streaming remains stable.

Viewport behavior remains predictable.

Optimization improves efficiency without changing experience.

The user never thinks about performance.

---

# 13. FUTURE EXTENSION RULES

## Purpose

The Future Extension Rules define how new capabilities are introduced without compromising the Conversation Architecture.

An LLM application will continue to evolve.

New capabilities may include:

* Voice interaction
* Images
* Files
* Artifacts
* Search
* Tools
* Agents
* Multimodal responses
* External actions

The architecture must support growth without creating disconnected experiences.

---

# 13.1 EXTENSION RESPONSIBILITY

The Extension System owns:

* Integration rules
* Capability boundaries
* Future compatibility
* Architectural consistency

The Extension System does not own:

* Conversation state
* Viewport behavior
* User intent
* Motion behavior
* Presentation decisions

New capabilities must integrate into existing systems.

---

# 13.2 EXTENSION PHILOSOPHY

New capabilities should feel like natural expressions of conversation.

They should not feel like separate products attached to the conversation.

The user should experience:

One conversation.

Many capabilities.

---

# 13.3 NO PARALLEL CONVERSATION MODELS

Future features must not create independent interaction models.

Avoid creating separate architectures for:

* Voice conversations
* Image conversations
* Agent conversations
* Tool conversations
* File conversations

All capabilities must participate in the same conversation lifecycle.

---

# 13.4 CAPABILITY INTEGRATION MODEL

New capabilities enter the system through existing boundaries.

The architecture remains:

User Intent

↓

Composer System

↓

Conversation Lifecycle

↓

Response Generation

↓

Viewport / Motion / Presentation

New capabilities may extend these systems.

They may not bypass them.

---

# 13.5 MULTIMODAL INPUT

All input types represent user intent.

Examples:

Text:

"I need help writing this."

Voice:

"I need help writing this."

Image:

"Analyze this image."

The underlying intent model remains consistent.

Input method should not determine architecture.

---

# 13.6 MULTIMODAL RESPONSE

Responses may contain multiple forms of information.

Examples:

* Text
* Images
* Generated content
* Interactive elements
* External actions

The conversation must still preserve:

* Sequence
* Context
* Ownership
* Reading flow

New content types must behave as part of the conversation.

---

# 13.7 TOOL AND AGENT EXTENSIONS

Tools and agents are participants in conversation state.

They should not create invisible system behavior.

The user should understand:

* What is happening
* Why it is happening
* What the next state will be

Agent actions must remain connected to conversational intent.

---

# 13.8 FUTURE EXTENSIONS AND VIEWPORT

New content types must respect existing viewport rules.

They must not create special-case scrolling behavior.

All content must follow:

* Viewport System
* Motion System
* Scroll Ownership System
* Reading Flow System

A new capability does not receive a new set of movement rules.

---

# 13.9 FUTURE EXTENSIONS AND OWNERSHIP

New capabilities must respect ownership.

They must not:

* Take control from the user
* Interrupt historical reading
* Override viewport decisions
* Force attention changes

New intelligence does not override user agency.

---

# 13.10 EXTENSION INVARIANTS

The following statements are always true.

✓ New features extend existing systems.

✓ New capabilities do not create parallel architectures.

✓ User intent remains the foundation.

✓ Conversation remains the primary interaction model.

✓ New content types respect viewport rules.

✓ New features preserve ownership rules.

✓ New capabilities preserve reading flow.

✓ Future expansion does not require rewriting core architecture.

---

# 13.11 ENGINEERING GUIDANCE

When adding a new capability:

Do not ask:

"How do we make this feature work?"

Ask:

"Which existing system should own this behavior?"

Every behavior must have a home.

If a feature requires bypassing existing architecture, the architecture should be reconsidered before implementation.

---

# 13.12 COMMON FAILURE MODES

The following conditions represent architectural failures:

• Creating separate interaction models for new features.

• Adding exceptions instead of extending systems.

• Allowing features to bypass viewport rules.

• Allowing tools or agents to control presentation.

• Treating multimodal content as separate experiences.

• Creating feature-specific ownership models.

• Allowing future capabilities to break conversation continuity.

---

# 13.13 SUCCESS CRITERIA

The Future Extension Rules succeed when:

New capabilities feel native.

The conversation remains the center of the experience.

The architecture scales without fragmentation.

Future features add capability without adding complexity.

The system can evolve without losing its original interaction principles.

---

# 14. ACCEPTANCE CRITERIA

## Purpose

The Acceptance Criteria define the conditions required for the Conversation Architecture to be considered complete.

These criteria validate the system as a whole.

A successful implementation should not only function.

It should preserve the intended conversational experience.

The acceptance criteria evaluate:

* Predictability
* User control
* Conversational continuity
* Spatial consistency
* System coherence

---

# 14.1 ARCHITECTURAL VALIDATION

The implementation is considered valid when:

The conversation behaves as a unified system.

Individual features do not operate independently.

All interaction decisions follow the established architecture:

User Intent

↓

Conversation State

↓

Viewport State

↓

Motion State

↓

Presentation

---

# 14.2 VIEWPORT ACCEPTANCE CRITERIA

The viewport system succeeds when:

✓ The conversation has predictable resting positions.

✓ The active exchange naturally receives priority.

✓ The user does not experience uncontrolled movement.

✓ Over-drag interactions recover predictably.

✓ Boundary behavior feels intentional.

✓ The viewport never enters an undefined state.

✓ Historical exploration preserves user position.

✓ Returning to live conversation restores the active state.

---

# 14.3 MOTION ACCEPTANCE CRITERIA

The motion system succeeds when:

✓ Movement communicates meaningful state changes.

✓ Motion does not exist purely for decoration.

✓ Transitions preserve orientation.

✓ The user understands why movement occurred.

✓ Motion never competes with reading.

✓ Reduced motion preferences can be respected without changing behavior.

---

# 14.4 OWNERSHIP ACCEPTANCE CRITERIA

The ownership system succeeds when:

✓ The viewport always has a clear owner.

✓ User control overrides system behavior.

✓ The system never interrupts intentional exploration.

✓ Automatic movement only occurs with system ownership.

✓ Ownership transitions are predictable.

✓ The user never wonders why the conversation moved.

---

# 14.5 READING FLOW ACCEPTANCE CRITERIA

The reading flow system succeeds when:

✓ The current exchange is visually prioritized.

✓ History remains accessible without overwhelming attention.

✓ Users maintain context during long conversations.

✓ Streaming preserves comprehension.

✓ The user focuses on conversation rather than navigation.

---

# 14.6 KEYBOARD ACCEPTANCE CRITERIA

The keyboard system succeeds when:

✓ Keyboard appearance feels like a natural environmental change.

✓ Input focus is preserved.

✓ The conversation remains understandable while typing.

✓ Keyboard transitions do not disrupt reading.

✓ Keyboard behavior does not control conversation state.

✓ The user never needs to manually recover their context.

---

# 14.7 COMPOSER ACCEPTANCE CRITERIA

The composer system succeeds when:

✓ User intent is preserved.

✓ Drafts remain safe.

✓ Submission is intentional.

✓ The composer feels connected to conversation.

✓ Future input methods can integrate naturally.

✓ Input mechanics never dominate the experience.

---

# 14.8 CONVERSATION LIFECYCLE ACCEPTANCE CRITERIA

The lifecycle system succeeds when:

✓ Every state has a clear owner.

✓ Every transition has a known destination.

✓ User actions create intentional transitions.

✓ System processes remain understandable.

✓ Interrupted states recover gracefully.

✓ Conversation state is independent from presentation.

---

# 14.9 STREAMING ACCEPTANCE CRITERIA

The streaming system succeeds when:

✓ Responses feel continuous.

✓ Partial responses remain understandable.

✓ Streaming does not destabilize the viewport.

✓ Users can remain detached from generation.

✓ Completion feels natural.

✓ Interrupted generations preserve context.

---

# 14.10 HISTORY NAVIGATION ACCEPTANCE CRITERIA

The history system succeeds when:

✓ Users can explore previous context safely.

✓ Historical browsing does not interrupt active conversation.

✓ Returning to live conversation feels natural.

✓ The system maintains orientation.

✓ History remains part of one continuous conversation.

---

# 14.11 PERFORMANCE ACCEPTANCE CRITERIA

The performance system succeeds when:

✓ Large conversations behave like small conversations.

✓ Optimization does not alter behavior.

✓ Streaming remains stable at scale.

✓ State preservation remains reliable.

✓ Resource management does not reduce conversational quality.

---

# 14.12 EXTENSION ACCEPTANCE CRITERIA

Future capabilities succeed when:

✓ They integrate into existing systems.

✓ They preserve conversation as the primary interaction model.

✓ They respect ownership rules.

✓ They respect viewport rules.

✓ They do not create parallel architectures.

✓ They feel native to the conversation.

---

# 14.13 FINAL SYSTEM INVARIANTS

The following statements define the complete architecture.

✓ The user is always in control.

✓ The system understands when to guide and when to yield.

✓ The conversation always has a predictable spatial relationship.

✓ Motion communicates meaning.

✓ Viewport behavior is never accidental.

✓ Streaming feels like intelligence unfolding.

✓ History feels connected, not separate.

✓ The keyboard supports expression.

✓ The composer preserves intent.

✓ New capabilities extend rather than fragment the system.

✓ Performance never changes behavior.

✓ The user never manages the interface.

✓ The interface disappears and the conversation remains.

---

# 14.14 IMPLEMENTATION READINESS CRITERIA

The architecture is ready for implementation when:

* All systems have clear ownership boundaries.
* No behavior requires bypassing another system.
* Viewport rules are deterministic.
* Motion rules are predictable.
* State transitions are explicit.
* Future capabilities have defined integration paths.
* The user experience remains coherent across all states.

---

# 14.15 FINAL DEFINITION OF SUCCESS

The Conversation Architecture succeeds when:

The user feels like they are having a conversation.

Not operating an application.

The system feels intelligent because it understands intent.

The interface feels effortless because the architecture is predictable.

The technology disappears.

The conversation remains.
