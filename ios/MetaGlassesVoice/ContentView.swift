//
// ContentView — Main tab container for the Nutrition + Meta Glasses app.
// Replaced original debug UI with the full nutrition app TabView.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var wearablesVM: WearablesViewModel
    @StateObject private var nutritionVM = NutritionViewModel()
    @StateObject private var doctorVM    = DoctorViewModel()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home",    systemImage: "house.fill") }

            ScanView(wearablesVM: wearablesVM)
                .tabItem { Label("Scan",    systemImage: "camera.viewfinder") }

            FoodLogView()
                .tabItem { Label("Log",     systemImage: "list.bullet.clipboard.fill") }

            MonthlyHistoryView()
                .tabItem { Label("History", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .environmentObject(nutritionVM)
        .environmentObject(doctorVM)
        // Keep the Meta AI URL registration overlay
        .overlay { RegistrationView(viewModel: wearablesVM) }
        // Glasses wearable errors bubble up here
        .alert("Glasses Error", isPresented: $wearablesVM.isErrorPresented) {
            Button("OK") { wearablesVM.dismissError() }
        } message: {
            Text(wearablesVM.errorMessage)
        }
    }
}
