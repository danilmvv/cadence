import SwiftUI
import CadenceCore
import CadenceMotion

/// Единственный публичный вход в эффект `waitingState`.
///
/// Вызывающая сторона отдаёт время ожидания и (когда есть) прогресс своей
/// работы — что показать, решает `resolve(.waiting(elapsed:), in:)`, а не
/// эта вью. Пороги 1 с и 10 с не продублированы здесь: до секунды план
/// пуст, и вью рендерит `EmptyView()` — без рамки, без запаса под контент,
/// потому что мигающий меньше секунды индикатор делает интерфейс
/// субъективно медленнее, а не быстрее (см. секцию 6 спеки).
public struct CadenceWaitingIndicator: View {
    private let elapsed: Duration
    private let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    /// - Parameters:
    ///   - elapsed: сколько идёт ожидание. Считает вызывающая сторона —
    ///     резолвер не должен знать текущее время, иначе перестаёт быть
    ///     чистой функцией.
    ///   - progress: прогресс 0...1 собственной работы вызывающей стороны.
    ///     Используется, только если резолвер решит показать `.progress` —
    ///     до этого момента значение просто игнорируется.
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
                    // Деградация: Reduce Motion подменяет вид на .fade
                    // независимо от того, чем он был — шиммером или
                    // прогрессом. Показываем неподвижную заглушку: состояние
                    // не теряется, только уходит непрерывное движение.
                    CadenceSkeleton(spec: motion)

                case .progress:
                    CadenceProgressBar(progress: progress, spec: motion)

                case .timingOnly, .scale, .shake, .drawOn, .disintegrate, .reassemble:
                    // resolve(.waiting) никогда не возвращает эти виды —
                    // сюда мы попасть не должны. Явное перечисление, а не
                    // default, чтобы новый вид в MotionKind не провалился
                    // сюда молча.
                    EmptyView()
                }
            } else {
                // < 1 с: план пуст. Не спиннер, не пустая рамка — именно
                // ничего, потому что EmptyView() не резервирует место.
                EmptyView()
            }
        }
    }
}
