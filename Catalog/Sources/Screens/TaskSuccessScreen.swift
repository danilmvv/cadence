import SwiftUI
import Cadence

/// Confirmation that a task finished: the checkmark strokes itself once per tap,
/// and the success haptic comes from the same resolve(...) call inside
/// CadenceTaskSuccessIndicator.
struct TaskSuccessScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var completions = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Confirmation that a task finished. The checkmark draws itself on once per completion; the success haptic and the stroke's duration and curve both come from the same resolved plan, so nothing here is timed by hand.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            CadenceTaskSuccessIndicator(trigger: completions)
                .frame(width: 64, height: 64)

            Button("Complete task") {
                completions += 1
                counter.record("taskSuccess")
            }
            .buttonStyle(.borderedProminent)

            Text("Fired \(counter.count("taskSuccess")) times this session")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("taskSuccess")
    }
}
