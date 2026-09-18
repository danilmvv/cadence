import SwiftUI
import CadenceCore

/// Applies the modifier-family motion kinds to a view.
///
/// The first version reduced everything to one `phase: Bool`, which produced two
/// visible bugs: `.scale` left a button shrunk forever after the first tap (the
/// toggle flipped to `true` once and stuck), and `.fade` kept content invisible
/// because `onChange` never fires for a view that was just inserted — there is
/// no event to observe. Each kind has its own character, so the semantics are
/// written per kind rather than through a single flag: `.scale` and `.shake` are
/// one-shot pulses on a `trigger` change, while `.fade` is a reveal that has to
/// happen both on first appearance and again afterwards.
public struct CadenceMotionModifier<Trigger: Equatable>: ViewModifier {
    public let spec: MotionSpec?
    public let trigger: Trigger

    public init(spec: MotionSpec?, trigger: Trigger) {
        self.spec = spec
        self.trigger = trigger
    }

    // An arbitrary caller-supplied `Trigger: Equatable` (a custom state enum,
    // say) is not guaranteed Sendable, while the bodies below are built with
    // keyframeAnimator, whose internal closures Swift 6 wants Sendable-compatible
    // under strict concurrency. Threading `Sendable` through the whole public
    // `.cadence` API for that is not worth it: what reaches the child modifiers
    // below is an Int counter of our own, incremented on every change — Int is
    // already Sendable, and the generic parameter never leaks out of this file.
    @State private var pulse = 0

    public func body(content: Content) -> some View {
        Group {
            if let spec {
                bodyWithSpec(content: content, spec: spec)
            } else {
                content
            }
        }
        .onChange(of: trigger) { pulse += 1 }
    }

    @ViewBuilder
    private func bodyWithSpec(content: Content, spec: MotionSpec) -> some View {
        switch spec.kind {
        case .scale(let target):
            // A transient pulse: travel to the target and return to 1.0 within
            // one run of the timeline. That is exactly what
            // `keyframeAnimator(trigger:)` is for — it plays the timeline once
            // per trigger change, unlike toggled state, which stays at its end
            // point until the next toggle.
            content.modifier(ScalePulseModifier(target: target, duration: spec.duration.timeInterval, pulse: pulse))

        case .shake(let amplitude):
            // Same principle as `.scale`: one run per pulse change. `shakes`
            // goes 0 → 3; at shakes == 3 `ShakeEffect.horizontalDisplacement`
            // reaches zero (the decay has run out), so the end of the timeline
            // is visually identical to the resting state.
            content.modifier(ShakePulseModifier(amplitude: amplitude, duration: spec.duration.timeInterval, pulse: pulse))

        case .fade:
            // A reveal, not a toggle: it has to happen when the view appears
            // (when no `onChange` has fired, or ever will) and again on a
            // trigger change.
            content.modifier(FadeInModifier(spec: spec, pulse: pulse))

        case .timingOnly:
            // Cadence supplies only the timing and the haptic; the caller knows
            // and animates its own geometry, so nothing is touched visually.
            content

        case .disintegrate:
            // The same one-shot run as `.scale` and `.shake`, except progress
            // goes into a Metal shader. The branch is chosen by the motion kind
            // of an already-resolved plan, never by the environment: deciding
            // what the motion will be belongs entirely to the resolver.
            content.modifier(DisintegratePulseModifier(duration: spec.duration.timeInterval, pulse: pulse))

        case .shimmer, .progress, .drawOn:
            // View family: Cadence draws these itself, and they cannot be
            // expressed as a modifier — see `MotionKind.isModifierFamily`.
            // Ignored explicitly rather than through a `default`, so a newly
            // added kind cannot fall through here silently.
            content

        case .reassemble:
            // The same shader with progress running 1 -> 0. It works because
            // the shader is a pure function of progress: it keeps no state
            // between frames and has no idea which way it is being driven.
            content.modifier(ReassemblePulseModifier(duration: spec.duration.timeInterval, pulse: pulse))
        }
    }
}

/// A scale pulse: to the target and back to 1.0 within one run of the timeline.
///
/// A concrete type rather than a method on `CadenceMotionModifier<Trigger>`:
/// `keyframeAnimator`'s `content:` closure is declared such that Swift 6 tries
/// to capture the enclosing type's generic metatype whole, even when the closure
/// never uses it — hence a spurious Sendable warning. Moving this into a concrete
/// type that takes a plain `Int` removes the generic context and the warning
/// with it.
private struct ScalePulseModifier: ViewModifier {
    let target: Double
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: pulse) { view, scale in
            view.scaleEffect(CGFloat(scale))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(target, duration: duration / 2)
                CubicKeyframe(1.0, duration: duration / 2)
            }
        }
    }
}

/// A decaying shake: `ShakeEffect.shakes` goes 0 → 3 within one run of the
/// timeline. See `ScalePulseModifier` for why this is a concrete type.
private struct ShakePulseModifier: ViewModifier {
    let amplitude: Double
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: pulse) { view, shakes in
            view.modifier(ShakeEffect(amplitude: CGFloat(amplitude), shakes: shakes))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(CGFloat(3), duration: duration)
            }
        }
    }
}

/// Content revealing itself: 0 → 1 when the view appears, and again on every
/// `pulse` change. The reset before a replay is deliberately not wrapped in an
/// animation: SwiftUI captures the `@State` value at the moment of assignment,
/// and the animated transition that follows is measured from it, even if no
/// frame carrying the intermediate value was ever drawn.
private struct FadeInModifier: ViewModifier {
    let spec: MotionSpec
    let pulse: Int

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear { reveal() }
            .onChange(of: pulse) {
                isVisible = false
                reveal()
            }
    }

    private func reveal() {
        withAnimation(spec.animation) {
            isVisible = true
        }
    }
}
