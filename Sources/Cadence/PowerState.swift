import Foundation
import Observation

/// Режим энергосбережения меняется на ходу, поэтому его читают не разово,
/// а наблюдают: иначе signature-эффект останется дорогим до перезапуска.
@MainActor
@Observable
public final class PowerState {
    public static let shared = PowerState()

    public private(set) var isLowPower: Bool

    private init() {
        isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        // [weak self], а не PowerState.shared внутри замыкания: на момент
        // срабатывания наблюдателя shared мог ещё не быть присвоен —
        // обращение к нему из собственного init было бы реентрантным
        // чтением синглтона во время его же построения (зависание/рекурсия
        // на первом обращении). self здесь уже полностью инициализирован
        // (isLowPower выше присвоен), поэтому слабый захват self корректен.
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }
}
