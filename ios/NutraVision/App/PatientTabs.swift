import SwiftUI

/// Titled stand-in until a later task builds the real screen.
struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text("Coming soon."))
                .navigationTitle(title)
        }
    }
}

struct PatientTabs: View {
    var body: some View {
        TabView {
            PlaceholderScreen(title: "Dashboard").tabItem { Label("Dashboard", systemImage: "house") }
            PlaceholderScreen(title: "Diary").tabItem { Label("Diary", systemImage: "book") }
            PlaceholderScreen(title: "Add").tabItem { Label("Add", systemImage: "plus.circle.fill") }
            PlaceholderScreen(title: "Progress").tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            MoreView().tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
