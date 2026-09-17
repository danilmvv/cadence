import SwiftUI
import Cadence

struct ValidationFailureScreen: View {
    @State private var attempts = 0
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Input validation failure. Type anything other than 1234 and tap check.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Code", text: $code)
                .textFieldStyle(.roundedBorder)
                .cadence(.validationFailed, trigger: attempts)

            Button("Check") {
                if code != "1234" { attempts += 1 }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("validationFailure")
    }
}
