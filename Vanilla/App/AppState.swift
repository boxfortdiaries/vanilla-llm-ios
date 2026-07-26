import Foundation

/// App-wide state that outlives any single screen (spec §19.4: "App State
/// owns global preferences, appearance, routing"). Screen-local state stays
/// in each feature's own ViewModel — never here.
@Observable
final class AppState {
    var appearance: AppAppearance = .system
}

enum AppAppearance {
    case system
    case light
    case dark
}
