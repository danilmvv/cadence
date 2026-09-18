import SwiftUI
import CadenceCore

/// A determinate progress bar for a wait. View family: Cadence draws it itself —
/// `.progress` cannot be expressed as a modifier, see
/// `MotionKind.isModifierFamily`.
///
/// The caller computes `progress`: Cadence cannot estimate how long someone
/// else's work will take. Whether the fill animates or jumps, however, is decided
/// by the `spec` that came out of `resolve(.waiting(elapsed:), in:)` — this view
/// is only built once the plan has already chosen `.progress`, and it uses that
/// plan's timing rather than inventing its own.
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
