/// How often an effect is appropriate. Governs how hard it is to reach for,
/// but NOT how long it lasts — duration belongs to `ChangeClass`.
public enum Tier: Sendable, CaseIterable, Equatable {
    /// Hundreds of times per session.
    case workhorse
    /// A handful of times per session.
    case accent
    /// Once a session or less. Explicit opt-in only.
    case signature
}
