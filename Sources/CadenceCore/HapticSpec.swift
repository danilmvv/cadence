public enum HapticPattern: Sendable, Equatable, Hashable {
    case impactLight
    case impactMedium
    case selection
    case success
    case warning
    case error
    /// Затухающая continuous-фаза. Используется signature-эффектами.
    case decayingRumble(duration: Duration)
}

public struct HapticSpec: Sendable, Equatable, Hashable {
    public var pattern: HapticPattern
    /// Минимальный интервал между повторами одного паттерна.
    /// Без него selection на скролле даёт непрерывное жужжание.
    public var minimumInterval: Duration

    public init(pattern: HapticPattern, minimumInterval: Duration) {
        self.pattern = pattern
        self.minimumInterval = minimumInterval
    }
}
