import CoreHaptics
import OSLog
import UIKit
import CadenceCore

/// Playback through CoreHaptics, falling back to `UIFeedbackGenerator`.
@MainActor
public final class CoreHapticsOutput: HapticOutput {
    private static let log = Logger(subsystem: "Cadence", category: "haptics")

    /// Whether the device has a Taptic Engine. If not, haptics are a silent
    /// no-op while motion is unaffected: feedback must not vanish altogether.
    public let isAvailable: Bool
    private var engine: CHHapticEngine?

    public init() {
        isAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard isAvailable else {
            Self.log.notice("No Taptic Engine: haptics disabled, motion unaffected")
            return
        }
        do {
            let engine = try CHHapticEngine()
            // The engine stops when the app backgrounds and after a system
            // reset. Without these handlers the vibration silently disappears
            // until the app is relaunched.
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.restart(after: "reset") }
            }
            engine.stoppedHandler = { [weak self] reason in
                Self.log.notice("Engine stopped, reason \(reason.rawValue)")
                Task { @MainActor in self?.restart(after: "stopped") }
            }
            try engine.start()
            self.engine = engine
        } catch {
            Self.log.error("CHHapticEngine failed to start: \(error.localizedDescription)")
            engine = nil
        }
    }

    public func play(_ pattern: HapticPattern) {
        guard isAvailable, let engine else {
            fallback(pattern)
            return
        }
        do {
            let player = try engine.makePlayer(with: try Self.corePattern(for: pattern))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            Self.log.error("Playback failed: \(error.localizedDescription)")
            fallback(pattern)
        }
    }

    private func restart(after reason: String) {
        do {
            try engine?.start()
        } catch {
            Self.log.error("Restart after \(reason) failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Patterns

    private static func corePattern(for pattern: HapticPattern) throws -> CHHapticPattern {
        switch pattern {
        case .impactLight:
            return try CHHapticPattern(events: [transient(at: 0, intensity: 0.4, sharpness: 0.7)], parameters: [])
        case .impactMedium:
            return try CHHapticPattern(events: [transient(at: 0, intensity: 0.7, sharpness: 0.5)], parameters: [])
        case .selection:
            return try CHHapticPattern(events: [transient(at: 0, intensity: 0.35, sharpness: 0.8)], parameters: [])
        case .success:
            return try CHHapticPattern(events: [
                transient(at: 0, intensity: 0.5, sharpness: 0.6),
                transient(at: 0.11, intensity: 0.8, sharpness: 0.8),
            ], parameters: [])
        case .warning:
            return try CHHapticPattern(events: [
                transient(at: 0, intensity: 0.7, sharpness: 0.9),
                transient(at: 0.13, intensity: 0.7, sharpness: 0.9),
            ], parameters: [])
        case .error:
            return try CHHapticPattern(events: (0..<3).map {
                transient(at: Double($0) * 0.11, intensity: 0.85, sharpness: 0.95)
            }, parameters: [])
        case .decayingRumble(let duration):
            let seconds = duration.timeInterval
            return try CHHapticPattern(
                events: [continuous(at: 0, duration: seconds, intensity: 0.8, sharpness: 0.25)],
                parameterCurves: [
                    CHHapticParameterCurve(
                        parameterID: .hapticIntensityControl,
                        controlPoints: [
                            .init(relativeTime: 0, value: 1.0),
                            .init(relativeTime: seconds, value: 0.0),
                        ],
                        relativeTime: 0
                    )
                ]
            )
        case .custom(let composition):
            return try CHHapticPattern(events: composition.events.map(event(from:)), parameters: [])
        }
    }

    /// One composed event turned into its CoreHaptics counterpart.
    private static func event(from event: HapticEvent) -> CHHapticEvent {
        switch event.kind {
        case .transient:
            transient(
                at: event.time,
                intensity: Float(event.intensity),
                sharpness: Float(event.sharpness)
            )
        case .continuous:
            continuous(
                at: event.time,
                duration: event.duration,
                intensity: Float(event.intensity),
                sharpness: Float(event.sharpness)
            )
        }
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private static func continuous(
        at time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func fallback(_ pattern: HapticPattern) {
        guard isAvailable else { return }
        switch pattern {
        case .impactLight:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .impactMedium, .decayingRumble:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .custom:
            // No CoreHaptics engine means no composed patterns at all: a
            // hand-built rhythm cannot be approximated by a single system tap,
            // and pretending otherwise would make the editor lie.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
