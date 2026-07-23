import UIKit

/// Captures the real system keyboard show/hide animation duration and curve
/// (from `UIResponder`'s own notifications) so other animations that need to
/// move alongside the keyboard can match it exactly instead of guessing.
/// Confirmed via on-device logging in both chat and voice mode (per Dan
/// 2026-07-22): both report the identical `duration=0.383, curve=7` — this
/// is the real value, not an artifact of any one screen's view hierarchy.
@MainActor
enum KeyboardAnimationInfo {
    private(set) static var duration: TimeInterval = 0.25
    private(set) static var curveOptions: UIView.AnimationOptions = .curveEaseInOut

    private static var didObserve = false

    /// Idempotent — call from anywhere that's about to rely on `duration`/
    /// `curveOptions`; only the first call actually registers the observers.
    static func observeIfNeeded() {
        guard !didObserve else { return }
        didObserve = true
        for name in [UIResponder.keyboardWillShowNotification, UIResponder.keyboardWillHideNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { notification in
                guard let userInfo = notification.userInfo,
                      let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
                      let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
                else { return }
                Task { @MainActor in
                    KeyboardAnimationInfo.duration = duration
                    KeyboardAnimationInfo.curveOptions = UIView.AnimationOptions(rawValue: curveRaw << 16)
                }
            }
        }
    }
}
