import SwiftUI
import Cadence
import CadenceCore

/// Переключатели среды. Подменяют контекст целиком, поэтому деградацию
/// видно, не выходя в системные настройки устройства.
struct DegradationControls: View {
    @Binding var context: CadenceContext

    var body: some View {
        Section("Среда") {
            Toggle("Reduce Motion", isOn: $context.reduceMotion)
            Toggle("Reduce Transparency", isOn: $context.reduceTransparency)
            Toggle("Экономия энергии", isOn: $context.lowPower)
            Toggle("Хаптик доступен", isOn: $context.hapticsAvailable)
        }
    }
}
