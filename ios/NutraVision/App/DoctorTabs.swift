import SwiftUI

struct DoctorTabs: View {
    var body: some View {
        TabView {
            PlaceholderScreen(title: "Patients").tabItem { Label("Patients", systemImage: "person.2") }
            PlaceholderScreen(title: "Requests").tabItem { Label("Requests", systemImage: "tray") }
            MoreView().tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
