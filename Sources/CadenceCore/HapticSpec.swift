public enum HapticPattern: Sendable, Equatable, Hashable {
    case impactLight
    case impactMedium
    case selection
    case success
    case warning
    case error
    /// A continuous phase that decays. Used by signature effects.
    case decayingRumble(duration: Duration)
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
