/// Событие плюс среда даёт план обратной связи.
///
/// Чистая функция без сайд-эффектов, без SwiftUI и UIKit. Именно поэтому
/// правила ресерча можно проверить юнит-тестами: см. ResolverRuleTests.
public func resolve(_ event: RoutineInteraction, in context: CadenceContext) -> FeedbackPlan {
    degrade(baseline(for: event), in: context)
}

// MARK: - Таблица соответствий

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

/// Каскад появления: шаг 40 мс, суммарная задержка ограничена бюджетом
/// крупного перемещения. Без ограничения последняя ячейка длинного списка
/// ждёт секунды, и это читается как тормоза, а не как анимация.
func staggerDelay(for index: Int) -> Duration {
    guard index > 0 else { return .zero }
    return min(Duration.milliseconds(40) * index, MotionBudget.journey)
}

/// Три порога отклика. Единственное место, где тулкит прямо запрещает
/// показывать индикатор: до секунды он воспринимается мерцанием и делает
/// интерфейс субъективно медленнее, а не быстрее.
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

// MARK: - Деградация

/// Порядок важен: сначала подменяем движение, потом решаем судьбу хаптика,
/// иначе можно оставить хаптик без визуального сопровождения.
func degrade(_ plan: FeedbackPlan, in context: CadenceContext) -> FeedbackPlan {
    var plan = plan

    if context.reduceMotion, let motion = plan.motion {
        // Подмена, а не удаление: пользователь всё равно должен понять,
        // что состояние изменилось.
        plan.motion = MotionSpec(
            duration: min(motion.duration, MotionBudget.transition),
            delay: motion.delay,
            curve: .easeInOut,
            change: motion.change,
            kind: .fade
        )
    }

    if context.lowPower, plan.tier == .signature, let motion = plan.motion {
        // Шейдер, считающийся каждый кадр, — неподходящая нагрузка
        // при экономии энергии.
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

    // Хаптик не может быть единственным носителем информации.
    if plan.motion == nil {
        plan.haptic = nil
    }

    return plan
}

// MARK: - Signature

/// Редкие выразительные события. Отдельная перегрузка, потому что и тип
/// события отдельный: случайно вызвать её на обычном действии нельзя.
public func resolve(_ event: SignatureInteraction, in context: CadenceContext) -> FeedbackPlan {
    degrade(baseline(for: event), in: context)
}

func baseline(for event: SignatureInteraction) -> FeedbackPlan {
    switch event {
    case .destroyed:
        // 900 мс сознательно превышают бюджет крупного перемещения.
        // Основание эстетическое, не эмпирическое — см. docs/research/05-novelty.md,
        // грейд D. Плата за превышение — запертость за отдельным типом.
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(900),
                curve: .easeIn,
                change: .journey,
                kind: .disintegrate
            ),
            haptic: HapticSpec(
                pattern: .decayingRumble(duration: .milliseconds(900)),
                minimumInterval: .seconds(1)
            ),
            tier: .signature
        )

    case .summoned(let corner):
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(450),
                curve: .spring(response: 0.45, damping: 0.75),
                change: .journey,
                kind: .cornerReveal(corner: corner)
            ),
            haptic: HapticSpec(pattern: .impactMedium, minimumInterval: .milliseconds(500)),
            tier: .signature
        )
    }
}
