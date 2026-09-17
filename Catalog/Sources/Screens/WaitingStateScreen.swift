import SwiftUI
import Cadence
import CadenceCore

/// Показывает правило трёх порогов вживую: до секунды — ничего, от секунды
/// до десяти — скелетон, дальше — детерминированный прогресс.
///
/// Пороги здесь не продублированы: экран лишь считает реальное время и
/// прогресс симулированной загрузки, а решение «что показать» целиком
/// остаётся за resolve(...) внутри CadenceWaitingIndicator.
struct WaitingStateScreen: View {
    /// Длительность симулированной загрузки — придумана для демонстрации
    /// и к порогам резолвера отношения не имеет.
    private static let simulatedLoadDuration: TimeInterval = 14

    @Environment(FireCounter.self) private var counter
    @State private var startDate: Date?

    var body: some View {
        VStack(spacing: 24) {
            Text("Waiting state. Under one second, nothing is shown at all — an indicator that lives less than a second reads as a flicker and makes the interface feel slower, not faster. From one to ten seconds, a skeleton. Past ten seconds, a determinate progress bar you could cancel.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TimelineView(.periodic(from: .now, by: 0.05)) { timeline in
                let elapsed = elapsed(at: timeline.date)

                VStack(spacing: 12) {
                    CadenceWaitingIndicator(elapsed: elapsed, progress: progress(for: elapsed))

                    Text(caption(for: elapsed))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button(startDate == nil ? "Start simulated load" : "Restart") {
                    startDate = Date()
                    counter.record("waitingState")
                }
                .buttonStyle(.borderedProminent)

                if startDate != nil {
                    Button("Cancel", role: .destructive) {
                        startDate = nil
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Fired \(counter.count("waitingState")) times this session")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("waitingState")
    }

    private func elapsed(at now: Date) -> Duration {
        guard let startDate else { return .zero }
        return .seconds(max(0, now.timeIntervalSince(startDate)))
    }

    private func progress(for elapsed: Duration) -> Double {
        min(1, elapsed.timeInterval / Self.simulatedLoadDuration)
    }

    private func caption(for elapsed: Duration) -> String {
        guard startDate != nil, elapsed.timeInterval > 0 else {
            return "Load not started"
        }
        return String(format: "Elapsed: %.1f s", elapsed.timeInterval)
    }
}
