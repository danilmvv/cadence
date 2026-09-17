import SwiftUI
import CadenceCore

/// Галочка подтверждения. Видовое семейство: Cadence рисует её сама —
/// `.drawOn` не выражается модификатором, см. `MotionKind.isModifierFamily`.
///
/// Поведение целиком читается из `spec.kind`, уже прошедшего
/// `resolve(.taskSucceeded, in:)`: `.drawOn` — обводка прорисовывается по
/// контуру, `.fade` — Reduce Motion подменил вид, и уже готовая галочка
/// просто проявляется крестфейдом. Длительность и кривая — `spec.animation`,
/// не числа, придуманные в этом файле.
///
/// `pulse` — счётчик прогонов, растущий на каждое срабатывание события,
/// тот же приём, что у `ScalePulseModifier`/`ShakePulseModifier` в
/// `CadenceMotionModifier`: один прогон анимации на смену значения, и,
/// в отличие от `FadeInModifier`, без автопроигрыша на первом появлении —
/// `taskSucceeded` описывает разовое событие завершения задачи, а не
/// состояние контента, которое обязано быть видно сразу после монтирования.
/// До первого срабатывания галочки не видно вовсе.
public struct CadenceSuccessMark: View {
    public var spec: MotionSpec
    public var pulse: Int

    @State private var drawn: CGFloat = 0
    @State private var isVisible = false

    public init(spec: MotionSpec, pulse: Int) {
        self.spec = spec
        self.pulse = pulse
    }

    public var body: some View {
        switch spec.kind {
        case .drawOn:
            CheckmarkShape()
                .trim(from: 0, to: drawn)
                .stroke(Color.accentColor, style: strokeStyle)
                .aspectRatio(1, contentMode: .fit)
                .onChange(of: pulse) {
                    drawn = 0
                    withAnimation(spec.animation) { drawn = 1 }
                }

        case .fade:
            CheckmarkShape()
                .trim(from: 0, to: 1)
                .stroke(Color.accentColor, style: strokeStyle)
                .aspectRatio(1, contentMode: .fit)
                .opacity(isVisible ? 1 : 0)
                .onChange(of: pulse) {
                    isVisible = false
                    withAnimation(spec.animation) { isVisible = true }
                }

        case .timingOnly, .scale, .shake, .shimmer, .progress, .disintegrate, .cornerReveal:
            // resolve(.taskSucceeded) никогда не возвращает эти виды — сюда
            // мы попасть не должны. Явное перечисление, а не default, чтобы
            // новый вид в MotionKind не провалился сюда молча.
            EmptyView()
        }
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
    }
}

/// Галочка как путь из двух отрезков. Приватная: наружу нужна только
/// готовая вью `CadenceSuccessMark`, не форма сама по себе.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.52)
        let mid = CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.75)
        let end = CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.28)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}
