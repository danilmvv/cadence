import SwiftUI
import Cadence
import CadenceCore

/// Переключатели среды. Подменяют контекст целиком, поэтому деградацию
/// видно, не выходя в системные настройки устройства.
struct DegradationControls: View {
    @Binding var context: CadenceContext

    var body: some View {
        Section("Environment") {
            Toggle("Reduce Motion", isOn: $context.reduceMotion)
            Toggle("Reduce Transparency", isOn: $context.reduceTransparency)
            Toggle("Low Power Mode", isOn: $context.lowPower)
            Toggle("Haptics Available", isOn: $context.hapticsAvailable)
        }
    }
}
