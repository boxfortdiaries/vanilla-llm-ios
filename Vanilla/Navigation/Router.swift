import SwiftUI

/// Owns the navigation stack's path (spec §7.1: NavigationStack + NavigationPath).
/// Holds state only — intent-based navigation methods live on
/// `NavigationCoordinator`. Injected via `.environment`, never a singleton.
@Observable
final class Router {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
