import SwiftUI
import CadenceCore

public extension MotionSpec {
    /// The SwiftUI animation this spec describes. The cascade delay is folded in.
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
