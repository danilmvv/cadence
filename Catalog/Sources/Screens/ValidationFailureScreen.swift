import SwiftUI
import Cadence

struct ValidationFailureScreen: View {
    @State private var attempts = 0
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Ошибка ввода. Введи что угодно кроме 1234 и нажми проверить.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Код", text: $code)
                .textFieldStyle(.roundedBorder)
                .cadence(.validationFailed, trigger: attempts)

            Button("Проверить") {
                if code != "1234" { attempts += 1 }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("validationFailure")
    }
}
