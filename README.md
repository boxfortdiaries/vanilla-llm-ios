# LLM-iOS

A ChatGPT / Claude–style LLM chat client for iOS 26, built in SwiftUI (Swift 6).
Single-root conversation with a slide-over drawer, Liquid Glass UI, and a
full-screen conversation search that morphs out of the drawer's search button.
The AI layer is a mock (`MockAIService`) behind an `AIService` protocol.

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
  Features/      Conversation surface (view + view model + state)
  Components/    Chat, Foundation, Artifact, Search, Settings views
  Models/        Conversation, Message, Artifact, Attachment
  Navigation/    Coordinator + router
  Services/      AIService protocol + mock, conversation store
  Theme/         Color, typography, spacing, radius, animation tokens
```
