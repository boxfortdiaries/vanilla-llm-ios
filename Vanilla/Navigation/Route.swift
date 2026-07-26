import Foundation

/// Pushable destinations (spec Appendix A). Home is the NavigationStack's
/// root content, not a pushed route. Only routes with a real destination
/// screen belong here — Artifact/Search/Settings routes are added when
/// those screens are built, not stubbed in ahead of time.
enum Route: Hashable {
    case conversation(id: UUID)
}
