import SwiftUI
import Cadence
import CadenceMotion

/// The Thanos snap. The screen shows two things at once: where the effect is
/// warranted and where it does harm. The second is not decoration — the point of
/// the signature tier is that the effect has a boundary, and a boundary is only
/// visible through an example of it being crossed.
struct DisintegrateScreen: View {
    @Environment(FireCounter.self) private var counter

    @State private var destroyCount = 0
    @State private var isDestroyed = false
    @State private var tuning = DisintegrationTuning.standard

    @State private var misuseCount = 0
    @State private var misuseGeneration = 0
    @State private var unreadCount = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro
                Divider()
                whereItBelongs
                Divider()
                whereItDoesNot
            }
            .padding()
        }
        .navigationTitle("disintegrate")
    }

    private var intro: some View {
        Text("Irreversible deletion. A Metal layer effect cuts the view into irregular shards — a weighted Voronoi over a jittered grid, so the pieces come out in different sizes rather than as tiles — and flies each one away as a rigid body, with its own start time, direction, speed and spin. The breakup sweeps diagonally across the card instead of letting go all at once, and each shard's alpha lags its movement so the piece is still solid while it travels. 1200 ms — deliberately over the large-movement budget, which is the whole reason this effect is locked behind an explicit opt-in.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: - Where it belongs

    private var whereItBelongs: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Where it belongs", detail: "Permanently deleting something the user cannot get back. The weight of the animation matches the weight of the act.")

            archiveCard
                .frame(height: 148)
                .cadenceDisintegration(isDestroyed: isDestroyed, tuning: tuning)

            HStack(spacing: 12) {
                Button("Delete forever", role: .destructive) {
                    guard !isDestroyed else { return }
                    isDestroyed = true
                    destroyCount += 1
                    counter.record("disintegrate")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDestroyed)

                Button("Restore") {
                    isDestroyed = false
                }
                .buttonStyle(.bordered)
                .disabled(!isDestroyed)
            }

            Text("Fired \(counter.count("disintegrate")) times this session")
                .font(.caption)
                .foregroundStyle(.secondary)

            tuningPanel
        }
    }

    // MARK: - Tuning the break-up's character

    private var tuningPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Character")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Reset") { tuning = .standard }
                    .font(.caption)
                    .disabled(tuning == .standard)
            }

            tuningSlider("Shard size", value: $tuning.shardSize, range: 8...60, unit: "pt",
                         hint: "Smaller means more pieces")
            tuningSlider("Size spread", value: $tuning.sizeVariation, range: 0...0.9,
                         hint: "At zero every piece is the same size and reads as procedural")
            tuningSlider("Drift", value: $tuning.drift, range: 0.3...2.5,
                         hint: "How far a shard travels — the duration stays fixed at 1200 ms")
            tuningSlider("Scatter", value: $tuning.scatter, range: 0...1,
                         hint: "At zero everything flies straight out from the centre")
            tuningSlider("Spin", value: $tuning.spin, range: 0...6,
                         hint: "Rotation of each shard about its own centre")
            tuningSlider("Sweep", value: $tuning.sweep, range: 0...1,
                         hint: "One means a clean wave across the card, zero means it just crumbles")

            Text("These are the only numbers in Cadence you are invited to change. The visual character of this effect is grade D in the research corpus — admitted taste, not evidence — so it belongs on a slider. Durations are not here: those come from perception thresholds and the resolver owns them.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func tuningSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String = "",
        hint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption.weight(.medium))
                Spacer()
                Text(unit.isEmpty
                     ? String(format: "%.2f", value.wrappedValue)
                     : String(format: "%.0f %@", value.wrappedValue, unit))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var archiveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lock.doc.fill")
                    .font(.title2)
                Spacer()
                Text("ARCHIVE")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
            }

            Spacer()

            Text("Family photos 2019–2024")
                .font(.headline)
            Text("1 284 items · 8,4 GB · no backup")
                .font(.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.36, green: 0.20, blue: 0.62), Color(red: 0.82, green: 0.29, blue: 0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Where it does not belong

    private var whereItDoesNot: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Where it does not", detail: "The same effect on a routine, reversible action in a list.")

            mailRow
                .cadenceSignature(.destroyed, trigger: misuseCount)
                .id(misuseGeneration)

            HStack(spacing: 12) {
                Button("Mark as read") {
                    misuseCount += 1
                    unreadCount = max(unreadCount - 1, 0)
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    misuseGeneration += 1
                    unreadCount = 3
                }
                .buttonStyle(.bordered)
            }

            Text("Why this is wrong: marking a message read is reversible and happens dozens of times a session, so tearing the row into flying debris for 1200 ms says the opposite of what the action means — and by holding the row for over a second it puts a ceiling on how fast the list can be worked through. An effect that reads as final has no business on anything undoable. This is also the only screen in the catalog that reaches for .cadenceSignature where the resolver would never have been asked: the opt-in makes the misuse deliberate, not accidental.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var mailRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.tint)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly digest")
                    .font(.subheadline.weight(.semibold))
                Text("\(unreadCount) unread in this thread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
