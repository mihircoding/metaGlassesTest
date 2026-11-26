import NutraCore
import SwiftUI

/// One cited guideline: title and publisher, opening the page in Safari.
struct SourceLink: View {
    let source: GuidanceSource

    var body: some View {
        Link(destination: source.url) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title).font(.subheadline).foregroundStyle(Color.primary)
                    Text(source.publisher).font(.caption).foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundStyle(Color.secondary).accessibilityHidden(true)
            }
        }
        .accessibilityHint("Opens in Safari")
    }
}
