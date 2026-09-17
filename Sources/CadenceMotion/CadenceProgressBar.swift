import SwiftUI
import CadenceCore

/// Детерминированная полоса прогресса ожидания. Видовое семейство: Cadence
/// рисует её сама — `.progress` не выражается модификатором, см.
/// `MotionKind.isModifierFamily`.
///
/// `progress` считает вызывающая сторона: Cadence не умеет оценивать
/// длительность чужой работы. А вот анимируется заливка или скачет —
/// решает `spec`, полученный через `resolve(.waiting(elapsed:), in:)`:
/// эта вью строится только тогда, когда план уже выбрал `.progress`, и
/// использует его тайминг, а не изобретает свой.
public struct CadenceProgressBar: View {
    public var progress: Double
    public var spec: MotionSpec

    public init(progress: Double, spec: MotionSpec) {
        self.progress = min(1, max(0, progress))
        self.spec = spec
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 8)
        .animation(spec.animation, value: progress)
    }
}
