import SwiftUI
import Cadence

struct ContentArrivalScreen: View {
    @State private var shown = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Content arriving in a cascade. The delay is capped by the large-movement budget — otherwise the last row would wait a full second, and that reads as lag rather than animation.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(shown ? "Hide" : "Show") { shown.toggle() }
                .buttonStyle(.bordered)

            if shown {
                VStack(spacing: 8) {
                    ForEach(0..<12, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.tint.opacity(0.2))
                            .frame(height: 28)
                            .cadence(.contentArrived(staggerIndex: index), trigger: shown)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("contentArrival")
    }
}
