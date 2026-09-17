import SwiftUI
import Cadence

struct ContentArrivalScreen: View {
    @State private var shown = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Появление контента каскадом. Задержка ограничена бюджетом крупного перемещения: иначе последняя ячейка ждёт секунды и это читается как тормоза.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(shown ? "Спрятать" : "Показать") { shown.toggle() }
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
