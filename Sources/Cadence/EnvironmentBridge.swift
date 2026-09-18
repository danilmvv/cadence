import SwiftUI
import CadenceCore

public extension CadenceContext {
    /// Builds a context out of environment values.
    ///
    /// Every input is passed explicitly and the function reads nothing from
    /// global state: that is the only way it can be asserted by a test.
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
    /// Replaces the context wholesale. Needed by the catalog and by previews so
    /// degradation can be shown without touching the device's system settings.
    @Entry var cadenceContextOverride: CadenceContext? = nil
}
