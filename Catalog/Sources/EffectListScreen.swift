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

                Section("Signature — explicit opt-in only") {
                    NavigationLink("disintegrate") { DisintegrateScreen() }
                    NavigationLink("cornerEmergence") { CornerEmergenceScreen() }
                }
            }
            .navigationTitle("Cadence")
        }
        .environment(\.cadenceContextOverride, context)
        .environment(counter)
    }
}
