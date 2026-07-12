import SwiftUI
import AVFoundation

/// A selectable assistant voice for live voice conversations. Backed by a
/// real on-device `AVSpeechSynthesisVoice` — no invented voice IDs, so every
/// option shown is guaranteed to actually speak.
struct VoiceOption: Identifiable, Equatable {
    var id: String { voiceIdentifier }
    let voiceIdentifier: String
    let name: String
    let description: String
    let gradient: [Color]

    static func == (lhs: VoiceOption, rhs: VoiceOption) -> Bool { lhs.voiceIdentifier == rhs.voiceIdentifier }
}

extension VoiceOption {
    /// Hand-written trait line for the well-known system voices, so the
    /// picker reads like ChatGPT's ("Confident and optimistic") rather than
    /// a raw language code. Anything not in this table gets a generic line.
    private static let knownDescriptions: [String: String] = [
        "Ava": "Warm and encouraging",
        "Samantha": "Clear and friendly",
        "Nathan": "Calm and steady",
        "Tom": "Confident and direct",
        "Zoe": "Bright and energetic",
        "Aaron": "Confident and optimistic",
        "Nicky": "Upbeat and casual",
        "Evan": "Thoughtful and measured",
    ]

    private static let gradients: [[Color]] = [
        [Color(red: 0.38, green: 0.36, blue: 0.95), Color(red: 0.85, green: 0.87, blue: 1.0)],
        [Color(red: 0.95, green: 0.55, blue: 0.35), Color(red: 1.0, green: 0.85, blue: 0.75)],
        [Color(red: 0.30, green: 0.75, blue: 0.65), Color(red: 0.80, green: 0.98, blue: 0.92)],
        [Color(red: 0.90, green: 0.40, blue: 0.55), Color(red: 1.0, green: 0.82, blue: 0.88)],
        [Color(red: 0.35, green: 0.60, blue: 0.95), Color(red: 0.80, green: 0.90, blue: 1.0)],
        [Color(red: 0.65, green: 0.55, blue: 0.95), Color(red: 0.90, green: 0.85, blue: 1.0)],
    ]

    /// Curated, de-duplicated-by-name list of installed en-US voices. Falls
    /// back to whatever English voices exist if none of the preferred names
    /// are present (e.g. a fresh simulator) — never returns empty as long as
    /// the system has at least one English voice, which it always does.
    static func availableVoices() -> [VoiceOption] {
        let systemVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        let preferredOrder = Array(knownDescriptions.keys)
        let preferred = systemVoices.filter { preferredOrder.contains($0.name) }
        let pool = preferred.isEmpty ? systemVoices : preferred

        // One entry per name (system ships multiple quality tiers of the same
        // voice) — prefer .enhanced/.premium over .default when duplicated.
        var byName: [String: AVSpeechSynthesisVoice] = [:]
        for voice in pool {
            if let existing = byName[voice.name], existing.quality.rawValue >= voice.quality.rawValue { continue }
            byName[voice.name] = voice
        }

        return byName.values
            .sorted { $0.name < $1.name }
            .enumerated()
            .map { index, voice in
                VoiceOption(
                    voiceIdentifier: voice.identifier,
                    name: voice.name,
                    description: knownDescriptions[voice.name] ?? "\(Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language) voice",
                    gradient: gradients[index % gradients.count]
                )
            }
    }
}
