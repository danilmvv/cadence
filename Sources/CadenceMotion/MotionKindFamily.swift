import CadenceCore

public extension MotionKind {
    /// Whether the kind is applied on top of the caller's own view.
    ///
    /// `false` means Cadence has to draw the view itself: a skeleton, a
    /// checkmark, a progress bar. Such kinds cannot be expressed as a modifier,
    /// and reaching for `CadenceMotionModifier` with one is a mistake.
    var isModifierFamily: Bool {
        switch self {
        case .timingOnly, .scale, .fade, .shake, .disintegrate, .reassemble:
            true
        case .shimmer, .progress, .drawOn:
            false
        }
    }
}
