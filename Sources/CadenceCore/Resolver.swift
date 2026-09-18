/// An event plus the environment yields a feedback plan.
///
/// A pure function: no side effects, no SwiftUI, no UIKit. That is precisely
/// what makes the research rules assertable by unit tests.
public func resolve(_ event: RoutineInteraction, in context: CadenceContext) -> FeedbackPlan {
    degrade(baseline(for: event), in: context)
}

// MARK: - The lookup table

func baseline(for event: RoutineInteraction) -> FeedbackPlan {
    switch event {
    case .pressed:
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.immediate,
                curve: .spring(response: 0.25, damping: 0.8),
                change: .direct,
                kind: .scale(to: 0.96)
            ),
            haptic: HapticSpec(pattern: .impactLight, minimumInterval: .milliseconds(40)),
            tier: .workhorse
        )

    case .selectionChanged:
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.immediate,
                curve: .easeInOut,
                change: .direct,
                kind: .timingOnly
            ),
            haptic: HapticSpec(pattern: .selection, minimumInterval: .milliseconds(80)),
            tier: .workhorse
        )

    case .contentArrived(let index):
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.transition,
                delay: staggerDelay(for: index),
                curve: .easeOut,
                change: .screen,
                kind: .fade
            ),
            haptic: nil,
            tier: .workhorse
        )

    case .waiting(let elapsed):
        waitingPlan(elapsed: elapsed)

    case .validationFailed:
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.transition,
                curve: .easeInOut,
                change: .screen,
                kind: .shake(amplitude: 8)
            ),
            haptic: HapticSpec(pattern: .error, minimumInterval: .milliseconds(500)),
            tier: .accent
        )

    case .taskSucceeded:
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(250),
                curve: .easeOut,
                change: .screen,
                kind: .drawOn
            ),
            haptic: HapticSpec(pattern: .success, minimumInterval: .milliseconds(500)),
            tier: .accent
        )
    }
}

/// Arrival cascade: a 40 ms step, with the total delay capped at the
/// large-movement budget. Uncapped, the last row of a long list waits for
/// seconds, and that reads as lag rather than as animation.
func staggerDelay(for index: Int) -> Duration {
    guard index > 0 else { return .zero }
    return min(Duration.milliseconds(40) * index, MotionBudget.journey)
}

/// The three response thresholds. The one place the toolkit forbids something
/// outright: under a second an indicator reads as a flicker and makes the
/// interface feel slower, not faster.
func waitingPlan(elapsed: Duration) -> FeedbackPlan {
    guard elapsed >= .seconds(1) else {
        return FeedbackPlan(motion: nil, haptic: nil, tier: .accent)
    }
    let kind: MotionKind = elapsed < .seconds(10) ? .shimmer : .progress
    return FeedbackPlan(
        motion: MotionSpec(
            duration: .milliseconds(1200),
            curve: .easeInOut,
            change: .persistent,
            kind: kind
        ),
        haptic: nil,
        tier: .accent
    )
}

// MARK: - Degradation

/// Order matters: substitute the motion first, then decide the haptic's fate.
/// The other way round can leave a haptic with nothing visual beside it.
func degrade(_ plan: FeedbackPlan, in context: CadenceContext) -> FeedbackPlan {
    var plan = plan

    if context.reduceMotion, let motion = plan.motion {
        // Substitution, not removal: the person still has to understand that
        // something changed.
        plan.motion = MotionSpec(
            duration: min(motion.duration, MotionBudget.transition),
            delay: motion.delay,
            curve: .easeInOut,
            change: motion.change,
            kind: .fade
        )
    }

    if context.lowPower, plan.tier == .signature, let motion = plan.motion {
        // A shader evaluated every frame is the wrong thing to run on a low
        // battery.
        plan.motion = MotionSpec(
            duration: min(motion.duration, MotionBudget.journey),
            delay: motion.delay,
            curve: .easeOut,
            change: .journey,
            kind: .fade
        )
    }

    if !context.hapticsAvailable || !context.sceneActive {
        plan.haptic = nil
    }

    // A haptic is never the sole carrier of information.
    if plan.motion == nil {
        plan.haptic = nil
    }

    return plan
}

// MARK: - Signature

/// Rare, expressive events. A separate overload because the event type is
/// separate too: it cannot be reached by accident from an ordinary action.
public func resolve(_ event: SignatureInteraction, in context: CadenceContext) -> FeedbackPlan {
    degrade(baseline(for: event), in: context)
}

func baseline(for event: SignatureInteraction) -> FeedbackPlan {
    switch event {
    case .destroyed:
        // 1200 ms deliberately exceeds the large-movement budget. The basis is
        // aesthetic, not empirical — see docs/research/05-novelty.md, grade D.
        // The price paid for exceeding it is being locked behind a separate type.
        //
        // It was 900 ms: the shards detach but never travel, so the break-up
        // wave and the scatter collapse into one smeared flash.
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(1200),
                curve: .easeIn,
                change: .journey,
                kind: .disintegrate
            ),
            haptic: HapticSpec(
                pattern: .decayingRumble(duration: .milliseconds(1200)),
                minimumInterval: .seconds(1)
            ),
            tier: .signature
        )

    case .restored:
        // The same duration as the break-up: reassembly is the same shader run
        // backwards, and different durations in the two directions would read
        // as a glitch rather than as intent.
        //
        // The haptic is softer: coming back is a smaller event than irreversible
        // deletion, and an identical kick would put the two on a par.
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(1200),
                curve: .easeOut,
                change: .journey,
                kind: .reassemble
            ),
            haptic: HapticSpec(pattern: .impactLight, minimumInterval: .milliseconds(500)),
            tier: .signature
        )
    }
}
