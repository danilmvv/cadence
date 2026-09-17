import CadenceCore

public extension MotionKind {
    /// Накладывается ли вид поверх вью вызывающей стороны.
    ///
    /// `false` означает, что Cadence обязан нарисовать вью сам: скелетон,
    /// галочку, полосу прогресса. Такие виды не выражаются модификатором,
    /// и попытка применить их через `CadenceMotionModifier` — ошибка.
    var isModifierFamily: Bool {
        switch self {
        case .timingOnly, .scale, .fade, .shake, .disintegrate:
            true
        case .shimmer, .progress, .drawOn, .cornerReveal:
            false
        }
    }
}
