import CadenceCore

/// Lets haptics through no faster than the spec allows.
///
/// Throttling is not a nicety: `selectionChanged` during a fast scroll, with no
/// rate limit, becomes continuous buzzing — the usual reason people switch
/// haptic feedback off entirely.
@MainActor
public final class HapticScheduler {
    private let output: HapticOutput
    private let now: () -> ContinuousClock.Instant
    private var lastFired: [HapticPattern: ContinuousClock.Instant] = [:]

    public init(
        output: HapticOutput,
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.output = output
        self.now = now
    }

    /// Returns `true` if the haptic actually played.
    /// Each pattern is throttled independently of the others.
    @discardableResult
    public func fire(_ spec: HapticSpec) -> Bool {
        let moment = now()
        if let last = lastFired[spec.pattern], moment - last < spec.minimumInterval {
            return false
        }
        lastFired[spec.pattern] = moment
        output.play(spec.pattern)
        return true
    }
}
