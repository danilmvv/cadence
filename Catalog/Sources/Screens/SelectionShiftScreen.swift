import SwiftUI
import Cadence

struct SelectionShiftScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Смена выбора. Cadence даёт тайминг и хаптик, геометрию двигает приложение. Хаптик троттлится: быстрые переключения не дают жужжания.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Раздел", selection: $selection) {
                Text("Один").tag(0)
                Text("Два").tag(1)
                Text("Три").tag(2)
            }
            .pickerStyle(.segmented)
            .cadence(.selectionChanged, trigger: selection)
            .onChange(of: selection) { counter.record("selectionShift") }

            Text("Сыграл \(counter.count("selectionShift")) раз за сессию")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("selectionShift")
    }
}
