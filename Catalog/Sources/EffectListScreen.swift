import SwiftUI
import Cadence
import CadenceCore

struct EffectListScreen: View {
    @State private var context = CadenceContext.standard
    @State private var counter = FireCounter()

    var body: some View {
        NavigationStack {
            List {
                DegradationControls(context: $context)

                Section("Workhorse — сотни раз за сессию") {
                    NavigationLink("pressResponse") { PressResponseScreen() }
                    NavigationLink("selectionShift") { SelectionShiftScreen() }
                    NavigationLink("contentArrival") { ContentArrivalScreen() }
                }

                Section("Accent — единицы раз за сессию") {
                    NavigationLink("validationFailure") { ValidationFailureScreen() }
                }

                Section("Ещё не реализовано") {
                    Text("Эти эффекты запланированы, но в пакете их пока нет: скелетон ожидания, галочка успеха, щелчок Таноса, выход из угла экрана.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cadence")
        }
        .environment(\.cadenceContextOverride, context)
        .environment(counter)
    }
}
