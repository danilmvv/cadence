import CadenceCore
import CadenceHaptics

/// The single owner of the haptic engine in the process.
///
/// A singleton is warranted here: CHHapticEngine is an expensive system
/// resource, and standing one up per modifier is not an option.
@MainActor
public final class CadenceRuntime {
    public static let shared = CadenceRuntime()

    private let output: CoreHapticsOutput
    public let scheduler: HapticScheduler

    public var hapticsAvailable: Bool { output.isAvailable }

    private init() {
        let output = CoreHapticsOutput()
        self.output = output
        self.scheduler = HapticScheduler(output: output)
    }
}
