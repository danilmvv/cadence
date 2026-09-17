import SwiftUI
import Cadence

struct PressResponseScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Press response. Budget: 100 ms — the threshold below which feedback is indistinguishable from directly manipulating the object.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Tap me") {
                taps += 1
                counter.record("pressResponse")
            }
            .buttonStyle(.borderedProminent)
            .cadence(.pressed, trigger: taps)

            Text("Fired \(counter.count("pressResponse")) times this session")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("pressResponse")
    }
}
