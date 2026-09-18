import SwiftUI
import CadenceCore
import CadenceMotion

/// The only public entry point to the `waitingState` effect.
///
/// The caller supplies how long the wait has run and, where it has one, the
/// progress of its own work. What to show is decided by
/// `resolve(.waiting(elapsed:), in:)`, not by this view. The 1 s and 10 s
/// thresholds are not duplicated here: under a second the plan is empty and the
/// view renders `EmptyView()` — no frame, no reserved space — because an
/// indicator that flickers for less than a second makes the interface feel
/// slower rather than faster (see section 6 of the spec).
public struct CadenceWaitingIndicator: View {
    private let elapsed: Duration
    private let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    /// - Parameters:
    ///   - elapsed: how long the wait has been running. The caller computes it:
    ///     the resolver must not know the current time, or it stops being a pure
    ///     function.
    ///   - progress: 0...1 progress of the caller's own work. Used only if the
    ///     resolver decides to show `.progress`; until then the value is simply
    ///     ignored.
    public init(elapsed: Duration, progress: Double = 0) {
        self.elapsed = elapsed
        self.progress = progress
    }

    public var body: some View {
        let context = override ?? CadenceContext.make(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: PowerState.shared.isLowPower,
            scenePhase: scenePhase,
            hapticsAvailable: CadenceRuntime.shared.hapticsAvailable
        )
        let plan = resolve(.waiting(elapsed: elapsed), in: context)

        Group {
            if let motion = plan.motion {
                switch motion.kind {
                case .shimmer:
                    CadenceSkeleton(spec: motion)

                case .fade:
                    // Degradation: Reduce Motion substitutes .fade for the kind,
                    // whatever it was — shimmer or progress. A still placeholder
                    // is shown: the state is not lost, only the continuous
                    // movement goes away.
                    CadenceSkeleton(spec: motion)

                case .progress:
                    CadenceProgressBar(progress: progress, spec: motion)

                case .timingOnly, .scale, .shake, .drawOn, .disintegrate, .reassemble:
                    // resolve(.waiting) never returns these kinds, so this
                    // branch should be unreachable. Listed explicitly rather than
                    // behind a default, so a newly added MotionKind cannot fall
                    // through silently.
                    EmptyView()
                }
            } else {
                // Under 1 s: the plan is empty. Not a spinner, not an empty
                // frame — nothing at all, because EmptyView() reserves no space.
                EmptyView()
            }
        }
    }
}
