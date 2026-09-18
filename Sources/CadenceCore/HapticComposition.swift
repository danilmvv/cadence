/// One event inside a composed haptic.
///
/// Deliberately a plain value with no CoreHaptics types in sight: `CadenceCore`
/// imports nothing, and a composition has to survive being written down, stored
/// and compared without a haptic engine anywhere near it.
public struct HapticEvent: Sendable, Equatable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Equatable, Hashable, CaseIterable {
        /// A single tap. `duration` is ignored.
        case transient
        /// A sustained buzz of `duration` seconds.
        case continuous
    }

    public var id: Int
    public var kind: Kind
    /// Offset from the start of the composition, in seconds.
    public var time: Double
    /// Length in seconds. Meaningful only for `.continuous`.
    public var duration: Double
    /// 0...1.
    public var intensity: Double
    /// 0...1. Low reads as a soft thud, high as a sharp click.
    public var sharpness: Double

    public init(
        id: Int = 0,
        kind: Kind,
        time: Double,
        duration: Double = 0.2,
        intensity: Double = 0.7,
        sharpness: Double = 0.5
    ) {
        self.id = id
        self.kind = kind
        self.time = time
        self.duration = duration
        self.intensity = intensity
        self.sharpness = sharpness
    }

    public static func transient(at time: Double, intensity: Double, sharpness: Double) -> HapticEvent {
        HapticEvent(kind: .transient, time: time, intensity: intensity, sharpness: sharpness)
    }

    public static func continuous(
        at time: Double,
        duration: Double,
        intensity: Double,
        sharpness: Double
    ) -> HapticEvent {
        HapticEvent(
            kind: .continuous,
            time: time,
            duration: duration,
            intensity: intensity,
            sharpness: sharpness
        )
    }
}

/// A haptic assembled by hand rather than chosen from the system vocabulary.
///
/// This exists so a pattern can be designed and felt before it is written into
/// the code. It travels through the same `HapticSpec` → scheduler → engine path
/// as every built-in pattern; there is no separate preview channel. That matters:
/// a haptic auditioned through a side channel would prove nothing about how it
/// lands in the app, where throttling and the scene's state also apply.
public struct HapticComposition: Sendable, Equatable, Hashable {
    public var name: String
    public var events: [HapticEvent]

    public init(name: String, events: [HapticEvent]) {
        self.name = name
        self.events = events
    }

    /// Total length in seconds, used to pace playback and to draw the timeline.
    public var duration: Double {
        events.map { $0.time + ($0.kind == .continuous ? $0.duration : 0) }.max() ?? 0
    }

    /// The composition written out as Swift, ready to paste into a project.
    ///
    /// The point of the whole feature: a haptic you liked has to leave the editor
    /// as something you can commit, not as a description you re-enter by hand.
    public var swiftLiteral: String {
        var lines = ["HapticComposition(name: \"\(name)\", events: ["]
        for event in events.sorted(by: { $0.time < $1.time }) {
            switch event.kind {
            case .transient:
                lines.append(
                    "    .transient(at: \(two(event.time)), "
                        + "intensity: \(two(event.intensity)), "
                        + "sharpness: \(two(event.sharpness))),"
                )
            case .continuous:
                lines.append(
                    "    .continuous(at: \(two(event.time)), "
                        + "duration: \(two(event.duration)), "
                        + "intensity: \(two(event.intensity)), "
                        + "sharpness: \(two(event.sharpness))),"
                )
            }
        }
        lines.append("])")
        return lines.joined(separator: "\n")
    }

    /// Two decimal places without Foundation. `String(format:)` would drag
    /// Foundation into `CadenceCore`, and this module importing nothing is the
    /// property that keeps the resolver testable in isolation.
    private func two(_ value: Double) -> String {
        let scaled = Int((value * 100).rounded())
        let whole = scaled / 100
        let fraction = abs(scaled % 100)
        return "\(whole).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    /// A single firm tap — the shortest thing that still counts as a haptic, and
    /// a reasonable place to start editing from.
    public static let starter = HapticComposition(
        name: "untitled",
        events: [.transient(at: 0, intensity: 0.7, sharpness: 0.5)]
    )
}
