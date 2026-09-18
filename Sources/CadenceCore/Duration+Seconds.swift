public extension Duration {
    /// Seconds as a `Double`. Needed at the boundary with SwiftUI `Animation`.
    var timeInterval: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
