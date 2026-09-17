import SwiftUI
import CadenceCore

/// Заглушка ожидания. Видовое семейство: Cadence рисует её сама — `.shimmer`
/// не выражается модификатором, см. `MotionKind.isModifierFamily`.
///
/// Аниматься ли — решает не этот файл. `spec.kind` уже прошёл резолвер и
/// деградацию: `.shimmer` — бегущий блик, `.fade` — Reduce Motion подменил
/// вид, и это значит неподвижную заглушку, а не анимированную. Ни порог
/// ожидания, ни выбор между скелетоном и прогрессом здесь не принимаются —
/// это исключительно дело `resolve(.waiting(elapsed:), in:)`.
public struct CadenceSkeleton: View {
    public var spec: MotionSpec
    public var cornerRadius: CGFloat
    public var height: CGFloat

    @State private var isSweeping = false

    public init(spec: MotionSpec, cornerRadius: CGFloat = 8, height: CGFloat = 44) {
        self.spec = spec
        self.cornerRadius = cornerRadius
        self.height = height
    }

    /// Единственное решение, которое принимает сама вью: рисовать бегущий
    /// блик или остаться неподвижной. Оба случая — валидные результаты
    /// резолвера, а не альтернативные реализации одного и того же вида.
    private var isAnimated: Bool { spec.kind == .shimmer }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.primary.opacity(0.08))
            .overlay {
                if isAnimated {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, .primary.opacity(0.16), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: isSweeping ? geometry.size.width : -geometry.size.width * 0.6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .onAppear {
                guard isAnimated else { return }
                // Длительность цикла блика — из resolve(...), а не выдумана
                // здесь: тот же `spec.duration`, что несёт таймингу резолвер.
                withAnimation(.linear(duration: spec.duration.timeInterval).repeatForever(autoreverses: false)) {
                    isSweeping = true
                }
            }
    }
}
