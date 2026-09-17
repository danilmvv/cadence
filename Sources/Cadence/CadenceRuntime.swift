import CadenceCore
import CadenceHaptics

/// Единственный владелец хаптик-движка в процессе.
///
/// Синглтон здесь оправдан: CHHapticEngine — дорогой системный ресурс,
/// и поднимать его на каждый модификатор нельзя.
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
