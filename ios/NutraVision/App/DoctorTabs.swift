import SwiftUI

struct DoctorTabs: View {
    var body: some View {
        TabView {
            PatientsView().tabItem { Label("Patients", systemImage: "person.2") }
            RequestsView().tabItem { Label("Requests", systemImage: "tray") }
            MoreView().tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
