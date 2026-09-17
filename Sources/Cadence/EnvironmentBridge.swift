import SwiftUI
import CadenceCore

public extension CadenceContext {
    /// Собирает контекст из значений среды.
    ///
    /// Все входы передаются явно и функция ничего не читает из глобального
    /// состояния: только так её можно проверить тестом.
    static func make(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        lowPower: Bool,
        scenePhase: ScenePhase,
        hapticsAvailable: Bool
    ) -> CadenceContext {
        CadenceContext(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: lowPower,
            hapticsAvailable: hapticsAvailable,
            sceneActive: scenePhase == .active
        )
    }
}

public extension EnvironmentValues {
    /// Подмена контекста целиком. Нужна каталогу и превью, чтобы показывать
    /// деградацию, не меняя системные настройки устройства.
    @Entry var cadenceContextOverride: CadenceContext? = nil
}
