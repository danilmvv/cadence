import SwiftUI
import Cadence
import CadenceCore

struct EffectListScreen: View {
    @State private var context = CadenceContext.standard
    @State private var counter = FireCounter()
    @State private var showsEnvironment = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Every duration here traces back to a source. How often an effect is appropriate decides how expressive it is allowed to be.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(EffectTier.allCases) { tier in
                        tierSection(tier)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Cadence")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CadenceHapticLab()
                    } label: {
                        Label("Haptic lab", systemImage: "waveform")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Haptic lab")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    environmentButton
                }
            }
            .navigationDestination(for: CatalogEffect.self) { destination(for: $0) }
            .sheet(isPresented: $showsEnvironment) {
                DegradationSheet(context: $context)
            }
        }
        .environment(\.cadenceContextOverride, context)
        .environment(counter)
    }

    // MARK: - Tier sections

    @ViewBuilder
    private func tierSection(_ tier: EffectTier) -> some View {
        let effects = CatalogEffect.allCases.filter { $0.tier == tier }

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.title)
                    .font(.title3.weight(.semibold))
                Text(tier.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Rare effects go in a single column and large, frequent ones in a
            // grid and small. Weight on screen carries meaning here, not taste.
            if tier == .signature {
                VStack(spacing: 12) {
                    ForEach(effects) { effect in
                        NavigationLink(value: effect) {
                            SignatureEffectCard(effect: effect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(effects) { effect in
                        NavigationLink(value: effect) {
                            EffectCard(effect: effect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Environment button

    private var environmentButton: some View {
        Button {
            showsEnvironment = true
        } label: {
            Label("Environment", systemImage: "slider.horizontal.3")
                .labelStyle(.iconOnly)
                // A non-default state shows at a glance: otherwise it is easy to
                // spend half an hour debugging a "broken" effect that is merely
                // degraded.
                .symbolVariant(context == .standard ? .none : .fill)
                .foregroundStyle(context == .standard ? Color.accentColor : Color.orange)
        }
        .accessibilityLabel("Environment overrides")
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destination(for effect: CatalogEffect) -> some View {
        switch effect {
        case .pressResponse: PressResponseScreen()
        case .selectionShift: SelectionShiftScreen()
        case .contentArrival: ContentArrivalScreen()
        case .waitingState: WaitingStateScreen()
        case .taskSuccess: TaskSuccessScreen()
        case .validationFailure: ValidationFailureScreen()
        case .disintegrate: DisintegrateScreen()
        }
    }
}
