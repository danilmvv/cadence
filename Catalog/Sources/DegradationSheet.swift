import SwiftUI
import Cadence
import CadenceCore

/// Переключатели среды. Подменяют контекст целиком, поэтому деградацию
/// видно, не выходя в системные настройки устройства.
///
/// Живут за кнопкой в тулбаре, а не на главном экране: это инструменты
/// отладки, а не содержание каталога.
struct DegradationSheet: View {
    @Binding var context: CadenceContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Reduce Motion", isOn: $context.reduceMotion)
                    Toggle("Reduce Transparency", isOn: $context.reduceTransparency)
                    Toggle("Low Power Mode", isOn: $context.lowPower)
                    Toggle("Haptics Available", isOn: $context.hapticsAvailable)
                } header: {
                    Text("Environment")
                } footer: {
                    Text("These override the real device settings for every effect in the catalog, so degradation can be inspected without leaving the app.")
                }

                if context != .standard {
                    Section {
                        Button("Reset to defaults") { context = .standard }
                    }
                }
            }
            .navigationTitle("Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
