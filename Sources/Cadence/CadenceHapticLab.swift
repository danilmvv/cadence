import SwiftUI
import UIKit
import CadenceCore
import CadenceHaptics

/// A workbench for designing a haptic by hand and feeling it before it is
/// written into the code.
///
/// Public on purpose, despite being a development tool rather than a component:
/// the whole value of it is auditioning a pattern inside the app it is meant for,
/// so it has to be droppable behind a debug menu in any project. Ship it behind
/// a build flag if that matters to you.
///
/// Playback goes through `CadenceRuntime.shared.scheduler`, exactly like every
/// effect in the toolkit. A preview on a side channel would prove nothing about
/// how the pattern lands in the app.
public struct CadenceHapticLab: View {
    @State private var composition = HapticComposition.starter
    @State private var nextID = 1
    @State private var lastPlayback: String?
    @State private var copied = false

    public init() {}

    private var hapticsAvailable: Bool { CadenceRuntime.shared.hapticsAvailable }

    public var body: some View {
        Form {
            if !hapticsAvailable {
                Section {
                    Label(
                        "This device has no Taptic Engine, so nothing here can be felt. The editor still works and the generated code is still correct — but judging a haptic requires real hardware.",
                        systemImage: "iphone.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }

            Section("Name") {
                TextField("Pattern name", text: $composition.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                ForEach($composition.events) { $event in
                    eventEditor($event)
                }
                .onDelete { composition.events.remove(atOffsets: $0) }

                HStack {
                    Button("Add tap") { add(.transient) }
                    Spacer()
                    Button("Add buzz") { add(.continuous) }
                }
                .font(.footnote)
            } header: {
                Text("Events")
            } footer: {
                Text("Intensity is how hard it hits. Sharpness is its character: low reads as a soft thud, high as a crisp click. Time places the event inside the pattern, so several events make a rhythm.")
            }

            Section {
                Button {
                    play()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .disabled(composition.events.isEmpty)

                if let lastPlayback {
                    Text(lastPlayback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(composition.swiftLiteral)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = composition.swiftLiteral
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy Swift", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            } header: {
                Text("Generated code")
            } footer: {
                Text("Paste this into your project and play it with HapticSpec(pattern: .custom(...)). Note that the system patterns above it — success, warning, selection — already mean something to people who use iOS. A custom rhythm carries no such shared meaning, so it is worth reserving for something the system vocabulary genuinely cannot say.")
            }
        }
        .navigationTitle("Haptic lab")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: composition) { copied = false }
    }

    // MARK: - Event editing

    @ViewBuilder
    private func eventEditor(_ event: Binding<HapticEvent>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Kind", selection: event.kind) {
                Text("Tap").tag(HapticEvent.Kind.transient)
                Text("Buzz").tag(HapticEvent.Kind.continuous)
            }
            .pickerStyle(.segmented)

            slider("Time", value: event.time, range: 0...1.5, unit: "s")
            if event.kind.wrappedValue == .continuous {
                slider("Duration", value: event.duration, range: 0.05...1, unit: "s")
            }
            slider("Intensity", value: event.intensity, range: 0...1)
            slider("Sharpness", value: event.sharpness, range: 0...1)
        }
        .padding(.vertical, 4)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String = ""
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .frame(width: 72, alignment: .leading)
            Slider(value: value, in: range)
            Text(unit.isEmpty
                 ? value.wrappedValue.formatted(.number.precision(.fractionLength(2)))
                 : value.wrappedValue.formatted(.number.precision(.fractionLength(2))) + unit)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func add(_ kind: HapticEvent.Kind) {
        // New events land after everything already there, so adding one never
        // silently reorders the rhythm you were building.
        let time = min((composition.duration + 0.12).rounded(toPlaces: 2), 1.5)
        composition.events.append(
            HapticEvent(id: nextID, kind: kind, time: time)
        )
        nextID += 1
    }

    private func play() {
        // minimumInterval is zero here, and only here: repeating the same pattern
        // over and over is the entire activity in a lab. In real use the interval
        // comes from the resolver, where it exists to stop a selection haptic
        // turning a scroll into continuous buzzing.
        let spec = HapticSpec(pattern: .custom(composition), minimumInterval: .zero)
        let played = CadenceRuntime.shared.scheduler.fire(spec)
        lastPlayback = played
            ? (hapticsAvailable ? "Played" : "Sent, but this device cannot play it")
            : "Throttled"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        var factor = 1.0
        for _ in 0..<places { factor *= 10 }
        return (self * factor).rounded() / factor
    }
}
