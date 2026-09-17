import SwiftUI
import CadenceCore
import CadenceMotion

/// Публичный вход в эффект `taskSuccess`: галочка и хаптик одним вызовом.
///
/// Симметрична `CadenceWaitingIndicator` — тоже строит контекст из среды и
/// отдаёт решение `resolve(.taskSucceeded, in:)`, не принимая его сама.
/// В отличие от ожидания, план `taskSucceeded` никогда не пуст (см.
/// `baseline(for: .taskSucceeded)` в Resolver.swift), поэтому здесь нет
/// ветки «ничего не показывать» — она была бы недостижимым кодом.
public struct CadenceTaskSuccessIndicator<Trigger: Equatable>: View {
    private let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    // Тот же приём, что у CadenceMotionModifier: наружу генерик-триггер, а
    // дочерней вью — свой Int-счётчик, растущий на каждую его смену.
    @State private var pulse = 0

    /// - Parameter trigger: меняется на каждое успешное завершение задачи.
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
