import SwiftUI
import CadenceCore
import CadenceMotion

public extension View {
    /// An everyday event: the resolver picks the motion and the haptic.
    func cadence<T: Equatable>(_ event: RoutineInteraction, trigger: T) -> some View {
        modifier(CadenceEventModifier(plan: { resolve(event, in: $0) }, trigger: trigger))
    }

    /// A rare, expressive event. A separate method and a separate event type:
    /// applying it to an ordinary action does not compile.
    func cadenceSignature<T: Equatable>(_ event: SignatureInteraction, trigger: T) -> some View {
        modifier(CadenceEventModifier(plan: { resolve(event, in: $0) }, trigger: trigger))
    }
}

struct CadenceEventModifier<T: Equatable>: ViewModifier {
    let plan: (CadenceContext) -> FeedbackPlan
    let trigger: T

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    func body(content: Content) -> some View {
        let context = override ?? CadenceContext.make(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: PowerState.shared.isLowPower,
            scenePhase: scenePhase,
            hapticsAvailable: CadenceRuntime.shared.hapticsAvailable
        )
        let resolved = plan(context)

        // Motion now drives itself from the trigger (CadenceMotionModifier works
        // the behaviour out per motion kind), so a separate `phase` is not needed
        // here — it would only be one more thing to fall out of sync.
        return content
            .modifier(CadenceMotionModifier(spec: resolved.motion, trigger: trigger))
            .onChange(of: trigger) {
                if let haptic = resolved.haptic {
                    CadenceRuntime.shared.scheduler.fire(haptic)
                }
            }
    }
}
