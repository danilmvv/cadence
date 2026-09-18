/// A snapshot of the environment a decision is made in. A value rather than a
/// reference, because the resolver has to stay pure.
public struct CadenceContext: Sendable, Equatable {
    public var reduceMotion: Bool
    public var reduceTransparency: Bool
    public var lowPower: Bool
    public var hapticsAvailable: Bool
    public var sceneActive: Bool

    public init(
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        lowPower: Bool = false,
        hapticsAvailable: Bool = true,
        sceneActive: Bool = true
    ) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.lowPower = lowPower
        self.hapticsAvailable = hapticsAvailable
        self.sceneActive = sceneActive
    }

    /// An ordinary device with nothing switched on.
    public static let standard = CadenceContext()
}
