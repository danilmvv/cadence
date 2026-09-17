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

                Section("Workhorse — hundreds of times per session") {
                    NavigationLink("pressResponse") { PressResponseScreen() }
                    NavigationLink("selectionShift") { SelectionShiftScreen() }
                    NavigationLink("contentArrival") { ContentArrivalScreen() }
                }

                Section("Accent — a handful of times per session") {
                    NavigationLink("waitingState") { WaitingStateScreen() }
                    NavigationLink("taskSuccess") { TaskSuccessScreen() }
                    NavigationLink("validationFailure") { ValidationFailureScreen() }
                }

                Section("Not yet built") {
                    Text("These effects are planned but not yet in the package: the Thanos snap and corner emergence.")
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
