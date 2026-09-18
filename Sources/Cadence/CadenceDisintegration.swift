import SwiftUI
import CadenceCore
import CadenceMotion

public extension View {
    /// The break-up and its reassembly, driven by state.
    ///
    /// Unlike `cadenceSignature(.destroyed, trigger:)`, which fires a one-shot
    /// pulse, this pair has two resting states and travels between them in both
    /// directions.
    ///
    /// - Parameters:
    ///   - isDestroyed: whether the view has broken up.
    ///   - tuning: the visual character of the break-up. These numbers are
    ///     aesthetics (grade D in the research corpus), which is why they are
    ///     tunable while the duration — set by the resolver — is not.
    ///   - collapsesLayout: whether to collapse the space taken up, so the
    ///     neighbouring elements reflow. The ordering is not cosmetic: on
    ///     deletion the space closes **after** the shards have gone, and on
    ///     restore it opens **before** they fly back. The reverse would look as
    ///     though the neighbours were twitching of their own accord.
    func cadenceDisintegration(
        isDestroyed: Bool,
        tuning: DisintegrationTuning = .standard,
        collapsesLayout: Bool = true
    ) -> some View {
        modifier(CadenceDisintegrationModifier(
            isDestroyed: isDestroyed,
            tuning: tuning,
            collapsesLayout: collapsesLayout
        ))
    }
}

struct CadenceDisintegrationModifier: ViewModifier {
    let isDestroyed: Bool
    let tuning: DisintegrationTuning
    let collapsesLayout: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    @State private var progress: Double = 0
    @State private var isCollapsed = false
    @State private var naturalHeight: CGFloat?

    /// Reflowing the neighbours is a noticeable screen change rather than direct
    /// manipulation, so it takes its own class's budget rather than the duration
    /// of the break-up itself.
    private var reflow: TimeInterval { MotionBudget.transition.timeInterval }

    func body(content: Content) -> some View {
        let context = override ?? CadenceContext.make(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: PowerState.shared.isLowPower,
            scenePhase: scenePhase,
            hapticsAvailable: CadenceRuntime.shared.hapticsAvailable
        )
        let plan = resolve(isDestroyed ? SignatureInteraction.destroyed : .restored, in: context)
        let usesShader = plan.motion.map(Self.isShaderKind) ?? false
        let duration = plan.motion?.duration.timeInterval ?? 0

        content
            // The environment may have downgraded the motion kind to a
            // cross-fade — in that case the shader is not run at all and opacity
            // does the work.
            .modifier(DisintegrationState(progress: usesShader ? progress : 0, tuning: tuning))
            .opacity(usesShader ? 1 : 1 - progress)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                // The measurement happens before the outer `frame`, so it picks
                // up the content's natural height rather than the collapsed one.
                if height > 0 { naturalHeight = height }
            }
            .frame(height: collapsesLayout ? collapsedHeight : nil)
            .clipped()
            .onChange(of: isDestroyed) { _, destroyed in
                animate(to: destroyed, duration: duration)
                if let haptic = plan.haptic {
                    CadenceRuntime.shared.scheduler.fire(haptic)
                }
            }
    }

    private var collapsedHeight: CGFloat? {
        guard let naturalHeight else { return nil }
        return isCollapsed ? 0 : naturalHeight
    }

    private func animate(to destroyed: Bool, duration: TimeInterval) {
        if destroyed {
            withAnimation(.linear(duration: duration)) { progress = 1 }
            guard collapsesLayout else { return }
            // The space closes only once there is nothing left to close over.
            withAnimation(.easeInOut(duration: reflow).delay(duration)) {
                isCollapsed = true
            }
        } else {
            guard collapsesLayout else {
                withAnimation(.linear(duration: duration)) { progress = 0 }
                return
            }
            // First the neighbours make room, then the shards fly back into the
            // space that opened up.
            withAnimation(.easeInOut(duration: reflow)) { isCollapsed = false }
            withAnimation(.linear(duration: duration).delay(reflow)) { progress = 0 }
        }
    }

    private static func isShaderKind(_ spec: MotionSpec) -> Bool {
        switch spec.kind {
        case .disintegrate, .reassemble: true
        default: false
        }
    }
}
