public extension Duration {
    /// Секунды как `Double`. Нужно на границе со SwiftUI `Animation`.
    var timeInterval: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
