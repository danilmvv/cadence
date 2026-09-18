import Foundation
import Observation

/// Low Power Mode changes while the app runs, so it is observed rather than read
/// once: otherwise a signature effect stays expensive until the next launch.
@MainActor
@Observable
public final class PowerState {
    public static let shared = PowerState()

    public private(set) var isLowPower: Bool

    private init() {
        isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        // [weak self] rather than PowerState.shared inside the closure: when the
        // observer fires, shared may not have been assigned yet — reaching for it
        // from its own init would be a reentrant read of the singleton during its
        // own construction (a hang or recursion on first access). self is fully
        // initialised by this point (isLowPower is assigned above), so capturing
        // it weakly is correct.
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }
}
