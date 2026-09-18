import SwiftUI

/// A compact card for frequent effects. There are many of them, so each takes
/// little room and keeps quiet — exactly what the toolkit demands of workhorse
/// effects themselves.
struct EffectCard: View {
    let effect: CatalogEffect

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: effect.symbol)
                .font(.title2)
                .foregroundStyle(effect.tier.tint)
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(effect.rawValue)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(effect.budget)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.6), lineWidth: 0.5)
        }
    }
}

/// A large card for rare, expressive effects. The size difference is not
/// decorative: room on screen is itself the message that this effect is
/// expensive and used sparingly.
struct SignatureEffectCard: View {
    let effect: CatalogEffect

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: effect.symbol)
                .font(.system(size: 34))
                .foregroundStyle(effect.tier.tint)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(effect.rawValue)
                        .font(.system(.headline, design: .monospaced))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(effect.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(effect.budget)
                    .font(.caption)
                    .foregroundStyle(effect.tier.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(effect.tier.tint.opacity(0.35), lineWidth: 1)
        }
    }
}
