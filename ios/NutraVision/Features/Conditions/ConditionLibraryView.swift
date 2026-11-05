import NutraCore
import SwiftUI

struct ConditionLibraryView: View {
    var body: some View {
        List(ConditionCatalog.all) { condition in
            NavigationLink {
                ConditionDetailView(condition: condition)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: condition.icon).foregroundStyle(Theme.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(condition.name).font(.headline)
                        Text(condition.summary).font(.footnote).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
            }
        }
        .navigationTitle("Conditions")
    }
}
