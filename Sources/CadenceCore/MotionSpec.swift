public enum Curve: Sendable, Equatable, Hashable {
    case easeIn
    case easeOut
    case easeInOut
    case spring(response: Double, damping: Double)
}

/// A declarative description of movement. Holds no views, which is what keeps
/// the resolver pure and testable without SwiftUI.
public enum MotionKind: Sendable, Equatable, Hashable {
    // Modifier family: applied on top of the caller's own view.

    /// Cadence supplies only the timing, the curve and the haptic; what moves
    /// is the app's decision. For cases where only the app knows the geometry —
    /// the indicator of a selected segment, say.
    case timingOnly
    case scale(to: Double)
    case fade
    case shake(amplitude: Double)

    // View family: Cadence has to draw the view itself.
    case shimmer
    case progress
    case drawOn

    // Require a Metal shader.
    case disintegrate
    /// The same shader, run backwards.
    case reassemble
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

    /// Whether the duration fits the budget of its change class.
    public var fitsBudget: Bool {
        guard let limit = MotionBudget.limit(for: change) else { return true }
        return duration <= limit
    }
}
