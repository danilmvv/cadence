/// What kind of change this is. Determines the duration budget.
///
/// Orthogonal to `Tier`: a frequent effect is allowed to be a slow screen
/// change, and a rare one is allowed to be quick.
public enum ChangeClass: Sendable, CaseIterable, Equatable {
    /// Direct manipulation of an object: a press, a drag.
    case direct
    /// A noticeable change on screen: content arriving, a modal.
    case screen
    /// A large movement across the screen.
    case journey
    /// An ongoing state rather than a transition: a loading skeleton.
    case persistent
}
