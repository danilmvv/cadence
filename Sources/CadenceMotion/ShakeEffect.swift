import SwiftUI

/// Затухающее горизонтальное колебание.
///
/// Отдельный `GeometryEffect`, а не `offset`: потряхивание — это колебание
/// во времени, одним сдвигом его не выразить. `animatableData` ведёт
/// счётчик колебаний от 0 до 3, амплитуда линейно гаснет к концу.
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

    /// Вынесено отдельно, чтобы математику затухания можно было проверить
    /// тестом, не собирая `ProjectionTransform`.
    public var horizontalDisplacement: CGFloat {
        let decay = max(0, 1 - shakes / 3)
        return amplitude * decay * sin(shakes * .pi * 2)
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: horizontalDisplacement, y: 0))
    }
}
