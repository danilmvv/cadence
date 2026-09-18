import SwiftUI

/// Уровень частоты. Несёт визуальный вес в каталоге: чем реже эффект
/// уместен, тем больше места он занимает на экране.
enum EffectTier: String, CaseIterable, Identifiable {
    case workhorse
    case accent
    case signature

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workhorse: "Workhorse"
        case .accent: "Accent"
        case .signature: "Signature"
        }
    }

    var caption: String {
        switch self {
        case .workhorse: "Hundreds of times per session"
        case .accent: "A handful of times per session"
        case .signature: "Once a session or less · explicit opt-in"
        }
    }

    var tint: Color {
        switch self {
        case .workhorse: .secondary
        case .accent: .blue
        case .signature: .orange
        }
    }
}

/// Один эффект в каталоге. Всё, что нужно карточке, лежит здесь, чтобы
/// корневой экран оставался про композицию, а не про содержание.
enum CatalogEffect: String, CaseIterable, Identifiable, Hashable {
    case pressResponse
    case selectionShift
    case contentArrival
    case waitingState
    case taskSuccess
    case validationFailure
    case disintegrate
    case cornerEmergence

    var id: String { rawValue }

    var tier: EffectTier {
        switch self {
        case .pressResponse, .selectionShift, .contentArrival: .workhorse
        case .waitingState, .taskSuccess, .validationFailure: .accent
        case .disintegrate, .cornerEmergence: .signature
        }
    }

    var symbol: String {
        switch self {
        case .pressResponse: "hand.tap"
        case .selectionShift: "switch.2"
        case .contentArrival: "rectangle.stack"
        case .waitingState: "hourglass"
        case .taskSuccess: "checkmark.seal"
        case .validationFailure: "exclamationmark.triangle"
        case .disintegrate: "sparkles"
        case .cornerEmergence: "arrow.up.left.square"
        }
    }

    /// Бюджет длительности — не украшение, а главная характеристика эффекта.
    var budget: String {
        switch self {
        case .pressResponse, .selectionShift: "100 ms · direct"
        case .contentArrival: "300 ms · screen"
        case .waitingState: "no budget · persistent"
        case .taskSuccess: "250 ms · screen"
        case .validationFailure: "300 ms · screen"
        case .disintegrate: "1200 ms · over budget"
        case .cornerEmergence: "450 ms · over budget"
        }
    }

    var blurb: String {
        switch self {
        case .pressResponse:
            "Under the threshold where a response stops reading as direct manipulation."
        case .selectionShift:
            "Timing and haptic only — your view moves its own indicator."
        case .contentArrival:
            "Ease-out with a stagger cascade that is capped, so the last row never lags."
        case .waitingState:
            "Nothing for a second, then a skeleton, then a determinate bar."
        case .taskSuccess:
            "A checkmark that draws itself on, with the system success haptic."
        case .validationFailure:
            "A shake that decays rather than stopping dead."
        case .disintegrate:
            "The card breaks into irregular shards that scatter and fade. Reserve it for deletion that cannot be undone."
        case .cornerEmergence:
            "An element flows out of the device's own screen corner, using the hardware radius rather than a guess."
        }
    }
}
