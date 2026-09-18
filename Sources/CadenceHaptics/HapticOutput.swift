import CadenceCore

/// Where a playback command goes. The protocol exists for testing: the
/// scheduler can be verified without hardware the simulator does not have.
@MainActor
public protocol HapticOutput: AnyObject {
    func play(_ pattern: HapticPattern)
}
