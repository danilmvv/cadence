import SwiftUI
import Cadence
import CadenceCore

/// Выход из угла экрана. Как и у `disintegrate`, на экране два примера
/// сразу: место, где эффект оправдан, и место, где он вредит. Граница
/// signature-эффекта видна только на примере её нарушения.
struct CornerEmergenceScreen: View {
    @Environment(FireCounter.self) private var counter

    @State private var corner: ScreenCorner = .topTrailing
    @State private var isAnnouncing = false
    @State private var isMisusing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro
                Divider()
                cornerPicker
                Divider()
                whereItBelongs
                Divider()
                whereItDoesNot
            }
            .padding()
        }
        .navigationTitle("cornerEmergence")
        // Оверлеи на всю сцену, а не внутри списка: иначе «угол экрана»
        // окажется углом ScrollView, и эффект станет обычным скруглённым
        // прямоугольником — как раз тем, чем он не является.
        .overlay {
            CadenceCornerEmergence(from: corner, isPresented: isAnnouncing) {
                statusPill
            }
            .ignoresSafeArea()
        }
        .overlay {
            CadenceCornerEmergence(from: corner, isPresented: isMisusing) {
                settingsPanel
            }
            .ignoresSafeArea()
        }
    }

    private var intro: some View {
        Text("An element flows out of the physical corner of the screen. The corner geometry is not guessed: the view reads the container's own corner insets and draws a ConcentricRectangle, so the curvature stays concentric with the hardware corner rather than approximating it. Inside a GlassEffectContainer the droplet in the corner and the element share one namespace, so the glass merges and pulls apart instead of cross-fading. 450 ms — deliberately over the large-movement budget, which is why the effect is locked behind an explicit opt-in.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var cornerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Corner")
                .font(.headline)
            Picker("Corner", selection: $corner) {
                Text("Top leading").tag(ScreenCorner.topLeading)
                Text("Top trailing").tag(ScreenCorner.topTrailing)
                Text("Bottom leading").tag(ScreenCorner.bottomLeading)
                Text("Bottom trailing").tag(ScreenCorner.bottomTrailing)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("The corner is part of the event, not a styling option: .summoned(from:) takes a ScreenCorner because the effect is built on that corner's radius.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Уместно

    private var whereItBelongs: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                "Where it belongs",
                detail: "A system-looking status notice, or an indicator of something happening in the background. It reports; it does not ask to be used."
            )

            HStack(spacing: 12) {
                Button(isAnnouncing ? "Dismiss" : "Announce") {
                    isAnnouncing.toggle()
                    if isAnnouncing {
                        counter.record("cornerEmergence")
                    }
                }
                .buttonStyle(.borderedProminent)

                if isMisusing {
                    Button("Hide the modal") { isMisusing = false }
                        .buttonStyle(.bordered)
                }
            }

            Text("Fired \(counter.count("cornerEmergence")) times this session")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.footnote.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Backup complete")
                    .font(.footnote.weight(.semibold))
                Text("2.4 GB · just now")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Неуместно

    private var whereItDoesNot: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                "Where it does not",
                detail: "The same effect carrying a content modal — a screen the user has to read, work through and dismiss."
            )

            Button(isMisusing ? "Close settings" : "Open settings from the corner") {
                isMisusing.toggle()
                if isMisusing {
                    counter.record("cornerEmergence")
                }
            }
            .buttonStyle(.bordered)

            Text("Why this is wrong: a corner is where the system speaks, not where the app's own content lives — so main navigation and content modals sent out of it arrive as notifications the user is meant to glance at and ignore, and the 450 ms flight is paid on every single entry into a screen people open constantly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            ForEach(["Notifications", "Appearance", "Storage", "Privacy"], id: \.self) { row in
                HStack {
                    Text(row)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 240)
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
