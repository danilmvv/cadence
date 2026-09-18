public enum HapticPattern: Sendable, Equatable, Hashable {
    case impactLight
    case impactMedium
    case selection
    case success
    case warning
    case error
    /// A continuous phase that decays. Used by signature effects.
    case decayingRumble(duration: Duration)
    /// A pattern assembled by hand rather than taken from the system vocabulary.
    ///
    /// Everything else in this enum maps onto a haptic the system already gives a
    /// meaning to, which is why the list is short: Apple's guidance is to keep
    /// system haptics meaning what the system means by them. A custom pattern
    /// carries no such guarantee, so it is worth naming the trade-off rather than
    /// letting it pass unnoticed.
    case custom(HapticComposition)
}

public struct HapticSpec: Sendable, Equatable, Hashable {
    public var pattern: HapticPattern
    /// Minimum interval between repeats of the same pattern.
    ///
    /// Without it, a selection haptic during a fast scroll turns into
    /// continuous buzzing — the usual reason people switch haptics off.
    public var minimumInterval: Duration

    public init(pattern: HapticPattern, minimumInterval: Duration) {
        self.pattern = pattern
        self.minimumInterval = minimumInterval
    }
}
