/// Снимок среды, в которой принимается решение. Значение, а не ссылка:
/// резолвер обязан быть чистым.
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

    /// Обычное устройство без ограничений.
    public static let standard = CadenceContext()
}
