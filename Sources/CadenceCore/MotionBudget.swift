/// Бюджеты длительности. Значения и источники — docs/research/01-timing.md.
public enum MotionBudget {
    /// Порог мгновенности: ниже него отклик неотличим от прямого манипулирования. [A]
    public static let immediate: Duration = .milliseconds(100)
    /// Заметная смена экрана. [B]
    public static let transition: Duration = .milliseconds(300)
    /// Верхняя граница для крупных перемещений. [B]
    public static let journey: Duration = .milliseconds(400)

    /// Предел для класса изменения. `nil` означает, что бюджет неприменим:
    /// длящееся состояние живёт столько, сколько идёт работа.
    public static func limit(for change: ChangeClass) -> Duration? {
        switch change {
        case .direct: immediate
        case .screen: transition
        case .journey: journey
        case .persistent: nil
        }
    }
}
