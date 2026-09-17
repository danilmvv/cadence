import CadenceCore

/// Пропускает хаптики не чаще, чем разрешает спека.
///
/// Троттлинг не украшение: `selectionChanged` на скролле без ограничения
/// частоты даёт непрерывное жужжание — типовая причина, по которой люди
/// отключают тактильную обратную связь целиком.
@MainActor
public final class HapticScheduler {
    private let output: HapticOutput
    private let now: () -> ContinuousClock.Instant
    private var lastFired: [HapticPattern: ContinuousClock.Instant] = [:]

    public init(
        output: HapticOutput,
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.output = output
        self.now = now
    }

    /// Возвращает `true`, если хаптик действительно сыграл.
    /// Каждый паттерн троттлится независимо от остальных.
    @discardableResult
    public func fire(_ spec: HapticSpec) -> Bool {
        let moment = now()
        if let last = lastFired[spec.pattern], moment - last < spec.minimumInterval {
            return false
        }
        lastFired[spec.pattern] = moment
        output.play(spec.pattern)
        return true
    }
}
