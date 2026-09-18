/// Everyday interface events.
///
/// A separate type from `SignatureInteraction`, and that separation is the main
/// mechanism by which the research reaches the call site: applying a signature
/// effect to an ordinary action is not discouraged by convention — it does not
/// compile.
public enum RoutineInteraction: Sendable, Equatable {
    /// A finger touched an interactive element.
    case pressed
    /// The selected item changed: a segment, a tab, a picker value.
    case selectionChanged
    /// Content arrived. `staggerIndex` is the item's position in the list.
    case contentArrived(staggerIndex: Int)
    /// A wait is in progress. The caller computes `elapsed`: the resolver must
    /// not know the current time, or it stops being a pure function.
    case waiting(elapsed: Duration)
    /// Input failed validation.
    case validationFailed
    /// A task finished successfully.
    case taskSucceeded
}

/// Events that warrant a rare, expressive effect.
public enum SignatureInteraction: Sendable, Equatable {
    /// Irreversible deletion.
    case destroyed
    /// Reassembly after `destroyed`: the shards fly back and reform.
    ///
    /// It exists for demonstration and for undo, not for symmetry. `destroyed`
    /// is by definition used where there is nothing to come back to, so this
    /// pair is rare in product code.
    case restored
}
