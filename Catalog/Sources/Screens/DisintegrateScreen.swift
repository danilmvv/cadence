import SwiftUI
import Cadence

/// Щелчок Таноса. Экран показывает две вещи сразу: место, где эффект
/// оправдан, и место, где он вредит. Второе — не украшение: смысл tier
/// signature в том, что у эффекта есть граница, а границу видно только
/// на примере её нарушения.
struct DisintegrateScreen: View {
    @Environment(FireCounter.self) private var counter

    @State private var destroyCount = 0
    @State private var isDestroyed = false

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

    // MARK: - Уместно

    private var whereItBelongs: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Where it belongs", detail: "Permanently deleting something the user cannot get back. The weight of the animation matches the weight of the act.")

            archiveCard
                .frame(height: 148)
                .cadenceDisintegration(isDestroyed: isDestroyed)

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

    // MARK: - Неуместно

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
