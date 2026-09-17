/// Результат резолвера: что показать и что дать почувствовать.
public struct FeedbackPlan: Sendable, Equatable {
    public var motion: MotionSpec?
    public var haptic: HapticSpec?
    public var tier: Tier

    public init(motion: MotionSpec?, haptic: HapticSpec?, tier: Tier) {
        self.motion = motion
        self.haptic = haptic
        self.tier = tier
    }

    public var isEmpty: Bool { motion == nil && haptic == nil }
}
