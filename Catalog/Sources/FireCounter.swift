import Observation

/// Делает понятие tier физически ощутимым: видно, сколько раз эффект
/// сыграл за сессию. Для workhorse счёт уходит в десятки за минуту,
/// для signature остаётся единичным.
@MainActor
@Observable
final class FireCounter {
    private(set) var counts: [String: Int] = [:]

    func record(_ effect: String) {
        counts[effect, default: 0] += 1
    }

    func count(_ effect: String) -> Int { counts[effect] ?? 0 }
}
