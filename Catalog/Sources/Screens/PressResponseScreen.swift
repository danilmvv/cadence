import SwiftUI
import Cadence

struct PressResponseScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Отклик на нажатие. Бюджет 100 мс — порог, ниже которого отклик неотличим от прямого манипулирования объектом.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Нажми") {
                taps += 1
                counter.record("pressResponse")
            }
            .buttonStyle(.borderedProminent)
            .cadence(.pressed, trigger: taps)

            Text("Сыграл \(counter.count("pressResponse")) раз за сессию")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("pressResponse")
    }
}
