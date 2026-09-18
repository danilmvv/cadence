import SwiftUI

/// A decaying horizontal oscillation.
///
/// A `GeometryEffect` rather than an `offset`: a shake is an oscillation over
/// time, and a single displacement cannot express it. `animatableData` carries
/// a count of oscillations from 0 to 3, with the amplitude fading linearly.
public struct ShakeEffect: GeometryEffect {
    public var amplitude: CGFloat
    public var shakes: CGFloat

    public init(amplitude: CGFloat, shakes: CGFloat) {
        self.amplitude = amplitude
        self.shakes = shakes
    }

    public var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    /// Exposed separately so the decay maths can be asserted by a test without
    /// assembling a `ProjectionTransform`.
    public var horizontalDisplacement: CGFloat {
        let decay = max(0, 1 - shakes / 3)
        return amplitude * decay * sin(shakes * .pi * 2)
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: horizontalDisplacement, y: 0))
    }
}
