import SwiftUI
import Cadence

struct SelectionShiftScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Selection shift. Cadence supplies the timing and the haptic; the app itself animates the geometry. The haptic is throttled, so fast switching never turns into a buzz.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Section", selection: $selection) {
                Text("One").tag(0)
                Text("Two").tag(1)
                Text("Three").tag(2)
            }
            .pickerStyle(.segmented)
            .cadence(.selectionChanged, trigger: selection)
            .onChange(of: selection) { counter.record("selectionShift") }

            Text("Fired \(counter.count("selectionShift")) times this session")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("selectionShift")
    }
}
