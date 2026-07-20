import UIKit

extension UIScreen {
    /// Replaces the deprecated `UIScreen.main` — iOS 26 wants the screen
    /// looked up through the active window scene instead. iPhone-only
    /// (`TARGETED_DEVICE_FAMILY: "1"`, no Stage Manager/multi-window), so
    /// there's only ever one scene/screen to find.
    static var current: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
    }
}
