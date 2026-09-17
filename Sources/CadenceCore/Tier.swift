/// Частота, с которой эффект уместен. Управляет строгостью опт-ина,
/// но НЕ длительностью — за длительность отвечает `ChangeClass`.
public enum Tier: Sendable, CaseIterable, Equatable {
    /// Сотни раз за сессию.
    case workhorse
    /// Единицы раз за сессию.
    case accent
    /// Раз в сессию и реже. Только по явному опт-ину.
    case signature
}
