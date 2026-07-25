# LLM-iOS

A ChatGPT / Claude–style LLM chat client for iOS 26, built in SwiftUI (Swift 6).
Single-root conversation with a slide-over drawer, Liquid Glass UI, a
full-screen conversation search that morphs out of the drawer's search button,
and a live hands-free voice conversation mode (mic → on-device speech
recognition → the normal chat pipeline → spoken reply). The AI layer is a
mock (`MockAIService`) behind an `AIService` protocol.

## Requirements

- Xcode 26+
- iOS 26 simulator or device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

The Xcode project is generated from `project.yml` and is **not** checked in.
Generate it, then open:

```sh
xcodegen generate
open LLM-iOS.xcodeproj
```

Run the `LLM-iOS` scheme on an iOS 26 simulator. After adding or removing
source files, re-run `xcodegen generate`.

## Structure

```
LLMApp/
  App/           App entry, container, root drawer/chat composition
  Features/      Conversation, Voice (live call UI + view model), Artifact,
                 Search, Settings screens (view + view model + state)
  Components/    Chat, Foundation, Artifact, Search, Settings, Voice views
  Models/        Conversation, Message, Artifact, Attachment, VoiceOption
  Navigation/    Coordinator + router
  Services/      AIService protocol + mock, conversation store
  Theme/         Color, typography, spacing, radius, animation tokens
  Utilities/     Helpers (keyboard animation capture, Markdown tables, sample
                 data) and Extensions

LLMDebugUITests/ Separate Xcode target — a manual repro harness for scroll
                  regressions (drives real sends via XCTest, screenshots each
                  settle point; no assertions, not part of CI). See
                  CONVERSATION-ARCHITECTURE.md §4.11/§4.12 (Scroll Ownership
                  System) for how to use it.
```
