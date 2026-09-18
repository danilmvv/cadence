import SwiftUI
import CadenceCore

/// A confirmation checkmark. View family: Cadence draws it itself — `.drawOn`
/// cannot be expressed as a modifier, see `MotionKind.isModifierFamily`.
///
/// The behaviour is read entirely from `spec.kind` after it has been through
/// `resolve(.taskSucceeded, in:)`: `.drawOn` strokes the mark along its path,
/// `.fade` means Reduce Motion substituted the kind and a finished checkmark
/// simply cross-fades in. Duration and curve come from `spec.animation`, not
/// from numbers invented in this file.
///
/// `pulse` is a run counter, incremented every time the event fires — the same
/// device as `ScalePulseModifier` and `ShakePulseModifier` in
/// `CadenceMotionModifier`: one run of the animation per change. Unlike
/// `FadeInModifier`, there is no autoplay on first appearance: `taskSucceeded`
/// describes a one-off completion event, not content that must be visible the
/// moment it mounts. Before the first firing, the checkmark is not shown at all.
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

        case .timingOnly, .scale, .shake, .shimmer, .progress, .disintegrate, .reassemble:
            // resolve(.taskSucceeded) never returns these kinds, so this branch
            // should be unreachable. Listed explicitly rather than behind a
            // default, so a newly added MotionKind cannot fall through silently.
            EmptyView()
        }
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
    }
}

/// The checkmark as a two-segment path. Private: only the finished
/// `CadenceSuccessMark` view is needed outside, not the shape itself.
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
