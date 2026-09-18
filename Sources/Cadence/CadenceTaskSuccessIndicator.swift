import SwiftUI
import CadenceCore
import CadenceMotion

/// The public entry point to the `taskSuccess` effect: checkmark and haptic in
/// one call.
///
/// Symmetrical with `CadenceWaitingIndicator` — it too builds a context from the
/// environment and hands the decision to `resolve(.taskSucceeded, in:)` rather
/// than making it. Unlike a wait, the `taskSucceeded` plan is never empty (see
/// `baseline(for: .taskSucceeded)` in Resolver.swift), so there is no
/// "show nothing" branch here; it would be unreachable code.
public struct CadenceTaskSuccessIndicator<Trigger: Equatable>: View {
    private let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    // The same device as CadenceMotionModifier: a generic trigger on the
    // outside, and an Int counter of our own — incremented on every change —
    // handed to the child view.
    @State private var pulse = 0

    /// - Parameter trigger: changes on every successful completion.
    public init(trigger: Trigger) {
        self.trigger = trigger
    }

    public var body: some View {
        let context = override ?? CadenceContext.make(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: PowerState.shared.isLowPower,
            scenePhase: scenePhase,
            hapticsAvailable: CadenceRuntime.shared.hapticsAvailable
        )
        let plan = resolve(.taskSucceeded, in: context)

        Group {
            if let motion = plan.motion {
                CadenceSuccessMark(spec: motion, pulse: pulse)
            } else {
                EmptyView()
            }
        }
        .onChange(of: trigger) {
            pulse += 1
            if let haptic = plan.haptic {
                CadenceRuntime.shared.scheduler.fire(haptic)
            }
        }
    }
}
