import SwiftUI
import CadenceCore
import CadenceMotion

public extension View {
    /// Повседневное событие: движение и хаптик подбирает резолвер.
    func cadence<T: Equatable>(_ event: RoutineInteraction, trigger: T) -> some View {
        modifier(CadenceEventModifier(plan: { resolve(event, in: $0) }, trigger: trigger))
    }

    /// Редкое выразительное событие. Отдельный метод и отдельный тип события:
    /// применить его к обычному действию не получится — не скомпилируется.
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

        // Движение теперь ведёт себя само по себе от trigger (CadenceMotionModifier
        // разбирает поведение по видам движения), поэтому отдельный `phase`
        // здесь не нужен — он остался бы лишним источником рассинхронизации.
        return content
            .modifier(CadenceMotionModifier(spec: resolved.motion, trigger: trigger))
            .onChange(of: trigger) {
                if let haptic = resolved.haptic {
                    CadenceRuntime.shared.scheduler.fire(haptic)
                }
            }
    }
}
