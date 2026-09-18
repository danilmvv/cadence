import SwiftUI
import CadenceCore
import CadenceMotion

public extension View {
    /// Распад и обратная сборка, управляемые состоянием.
    ///
    /// В отличие от `cadenceSignature(.destroyed, trigger:)`, который даёт
    /// разовый импульс, эта пара имеет два устойчивых состояния и ходит
    /// между ними в обе стороны.
    ///
    /// - Parameters:
    ///   - isDestroyed: распалась ли вью.
    ///   - collapsesLayout: схлопывать ли занимаемое место, чтобы соседние
    ///     элементы перестроились. Порядок здесь не косметический:
    ///     при удалении место закрывается **после** того, как осколки
    ///     улетели, при возврате — раскрывается **до** того, как они
    ///     слетятся. Обратный порядок выглядел бы так, будто соседи
    ///     дёргаются сами по себе, без причины.
    func cadenceDisintegration(
        isDestroyed: Bool,
        collapsesLayout: Bool = true
    ) -> some View {
        modifier(CadenceDisintegrationModifier(
            isDestroyed: isDestroyed,
            collapsesLayout: collapsesLayout
        ))
    }
}

struct CadenceDisintegrationModifier: ViewModifier {
    let isDestroyed: Bool
    let collapsesLayout: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    @State private var progress: Double = 0
    @State private var isCollapsed = false
    @State private var naturalHeight: CGFloat?

    /// Перестроение соседей — это заметное изменение экрана, а не прямое
    /// манипулирование, поэтому оно берёт бюджет своего класса, а не
    /// длительность самого распада.
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
            // Среда могла понизить вид движения до кросс-фейда — тогда
            // шейдер не запускаем вовсе и гасим прозрачностью.
            .modifier(DisintegrationState(progress: usesShader ? progress : 0))
            .opacity(usesShader ? 1 : 1 - progress)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                // Замер идёт до внешнего `frame`, поэтому берётся
                // естественная высота содержимого, а не уже схлопнутая.
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
            // Место закрывается только когда закрывать уже нечего.
            withAnimation(.easeInOut(duration: reflow).delay(duration)) {
                isCollapsed = true
            }
        } else {
            guard collapsesLayout else {
                withAnimation(.linear(duration: duration)) { progress = 0 }
                return
            }
            // Сначала соседи расступаются, потом в освободившееся место
            // слетаются осколки.
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
