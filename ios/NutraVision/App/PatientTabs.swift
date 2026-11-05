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
    @Environment(AppModel.self) private var app
    private enum Tab: Hashable { case dashboard, diary, add, progress, more }
    @State private var selection = Tab.dashboard
    @State private var showPlus = false

    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tag(Tab.dashboard).tabItem { Label("Dashboard", systemImage: "house") }
            NavigationStack {
                if let id = app.profile?.id { DiaryView(userId: id, readOnly: false) } else { ProgressView() }
            }
            .tag(Tab.diary).tabItem { Label("Diary", systemImage: "book") }
            Color.clear.tag(Tab.add).tabItem { Label("Add", systemImage: "plus.circle.fill") }
            NavigationStack {
                if let id = app.profile?.id {
                    NutritionProgressView(userId: id).navigationTitle("Progress")
                } else { ProgressView() }
            }
            .tag(Tab.progress)
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            MoreView().tag(Tab.more).tabItem { Label("More", systemImage: "ellipsis") }
        }
        // The plus tab is an action, not a screen: bounce back to the previous tab and open the sheet.
        .onChange(of: selection) { old, new in
            if new == .add {
                selection = old
                showPlus = true
            }
        }
        .sheet(isPresented: $showPlus) { PlusSheet() }
    }
}
