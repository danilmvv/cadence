import SwiftUI
import CadenceCore

/// A waiting placeholder. View family: Cadence draws it itself — `.shimmer`
/// cannot be expressed as a modifier, see `MotionKind.isModifierFamily`.
///
/// Whether it animates is not this file's decision. `spec.kind` has already been
/// through the resolver and through degradation: `.shimmer` means a travelling
/// highlight, `.fade` means Reduce Motion substituted the kind and the
/// placeholder should be still rather than animated. Neither the waiting
/// threshold nor the choice between skeleton and progress is made here — both
/// belong exclusively to `resolve(.waiting(elapsed:), in:)`.
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

    /// The only decision this view makes for itself: draw a travelling highlight
    /// or stay still. Both are valid resolver outcomes, not two implementations
    /// of the same kind.
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
                // The highlight's cycle length comes from resolve(...), not from
                // this file: the same `spec.duration` the resolver assigned.
                withAnimation(.linear(duration: spec.duration.timeInterval).repeatForever(autoreverses: false)) {
                    isSweeping = true
                }
            }
    }
}
