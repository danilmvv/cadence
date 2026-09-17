public enum Curve: Sendable, Equatable, Hashable {
    case easeIn
    case easeOut
    case easeInOut
    case spring(response: Double, damping: Double)
}

/// Угол экрана. Свой тип, а не SwiftUI `Edge`: эффект привязан к радиусу угла,
/// и Core не должен зависеть от SwiftUI.
public enum ScreenCorner: Sendable, Equatable, Hashable, CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

/// Декларативное описание движения. Не содержит вью — благодаря этому
/// резолвер остаётся чистым и тестируется без SwiftUI.
public enum MotionKind: Sendable, Equatable, Hashable {
    // Модификаторное семейство: накладывается поверх вью вызывающей стороны.

    /// Cadence даёт только тайминг, кривую и хаптик; что именно движется,
    /// решает приложение. Нужен там, где геометрию знает только оно —
    /// например, индикатор выбранного сегмента.
    case timingOnly
    case scale(to: Double)
    case fade
    case shake(amplitude: Double)

    // Видовое семейство: Cadence обязан нарисовать вью сам.
    case shimmer
    case progress
    case drawOn

    // Требуют шейдера или стекла. Реализуются вторым планом.
    case disintegrate
    case cornerReveal(corner: ScreenCorner)
}

public struct MotionSpec: Sendable, Equatable, Hashable {
    public var duration: Duration
    public var delay: Duration
    public var curve: Curve
    public var change: ChangeClass
    public var kind: MotionKind

    public init(
        duration: Duration,
        delay: Duration = .zero,
        curve: Curve,
        change: ChangeClass,
        kind: MotionKind
    ) {
        self.duration = duration
        self.delay = delay
        self.curve = curve
        self.change = change
        self.kind = kind
    }

    /// Укладывается ли длительность в бюджет своего класса изменения.
    public var fitsBudget: Bool {
        guard let limit = MotionBudget.limit(for: change) else { return true }
        return duration <= limit
    }
}
