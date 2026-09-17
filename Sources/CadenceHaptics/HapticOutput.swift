import CadenceCore

/// Куда уходит команда воспроизведения. Протокол существует ради тестов:
/// планировщик проверяется без железа, которого нет в симуляторе.
@MainActor
public protocol HapticOutput: AnyObject {
    func play(_ pattern: HapticPattern)
}
