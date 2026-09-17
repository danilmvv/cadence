import SwiftUI
import CadenceCore

public extension MotionSpec {
    /// SwiftUI-анимация, соответствующая спеке. Задержка каскада входит сюда.
    var animation: Animation {
        let seconds = duration.timeInterval
        let base: Animation = switch curve {
        case .easeIn: .easeIn(duration: seconds)
        case .easeOut: .easeOut(duration: seconds)
        case .easeInOut: .easeInOut(duration: seconds)
        case .spring(let response, let damping): .spring(response: response, dampingFraction: damping)
        }
        return delay == .zero ? base : base.delay(delay.timeInterval)
    }
}
