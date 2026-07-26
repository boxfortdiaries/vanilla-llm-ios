import UIKit

extension UIApplication {
    /// Dismisses whatever keyboard is currently up, regardless of which view
    /// owns the focused field. SwiftUI has no built-in "resign focus from
    /// anywhere" API — this is the standard UIKit-interop way to do it from a
    /// view (like the drawer) that doesn't own the composer's `@FocusState`.
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
