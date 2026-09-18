import Observation

/// Makes the notion of a tier tangible: you can see how many times an effect has
/// played this session. For workhorse the count runs into the dozens within a
/// minute; for signature it stays in single figures.
@MainActor
@Observable
final class FireCounter {
    private(set) var counts: [String: Int] = [:]

    func record(_ effect: String) {
        counts[effect, default: 0] += 1
    }

    func count(_ effect: String) -> Int { counts[effect] ?? 0 }
}
