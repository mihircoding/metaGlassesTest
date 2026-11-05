import NutraCore
import SwiftUI

extension VerdictLevel {
    var color: Color {
        switch self {
        case .goodFit: return Theme.good
        case .moderation: return Theme.moderation
        case .notRecommended: return Theme.bad
        }
    }
}

struct VerdictBadge: View {
    let verdict: Verdict

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(verdict.level.rawValue, systemImage: "circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(verdict.level.color)
            ForEach(Array(verdict.reasons.prefix(2).enumerated()), id: \.offset) { _, reason in
                Text(reason.text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Marks entries imported from Apple Health.
struct HealthHeart: View {
    var body: some View {
        Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityLabel("From Apple Health")
    }
}
