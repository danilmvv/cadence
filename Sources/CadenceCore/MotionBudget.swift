/// Duration budgets. Values and their sources: docs/research/01-timing.md.
public enum MotionBudget {
    /// The threshold of perceived instantaneity: below it a response is
    /// indistinguishable from direct manipulation. [A]
    public static let immediate: Duration = .milliseconds(100)
    /// A noticeable screen change. [B]
    public static let transition: Duration = .milliseconds(300)
    /// Upper bound for large movements. [B]
    public static let journey: Duration = .milliseconds(400)

    /// The limit for a change class. `nil` means no budget applies: an
    /// ongoing state lasts exactly as long as the work does.
    public static func limit(for change: ChangeClass) -> Duration? {
        switch change {
        case .direct: immediate
        case .screen: transition
        case .journey: journey
        case .persistent: nil
        }
    }
}
