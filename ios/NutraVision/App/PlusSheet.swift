import NutraCore
import SwiftUI

/// The ＋ tab's quick-add sheet. Exercise and weight are wired by Task 20.
struct PlusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var glassesMode: GlassesSource?
    @State private var showPhoto = false
    @State private var showBarcode = false
    @State private var showSearch = false
    @State private var scanned: FoodItem?
    @State private var lookingUp = false
    @State private var error: String?
    @State private var lastCode: String?

    private var meal: Meal { MealSlot.meal(at: Date()) }

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                        if let lastCode {
                            Button("Retry") { Task { await lookUp(lastCode) } }.buttonStyle(.bordered)
                        }
                    }
                }
                if lookingUp { ProgressView().frame(maxWidth: .infinity) }
                Menu {
                    Button("Meta glasses", systemImage: "eyeglasses") { glassesMode = .glasses }
                    Button("Phone camera", systemImage: "iphone") { glassesMode = .phone }
                } label: {
                    Label("Glasses Mode", systemImage: "eyeglasses")
                }
                Button { showPhoto = true } label: { Label("Photo scan", systemImage: "camera") }
                Button { showBarcode = true } label: { Label("Barcode", systemImage: "barcode.viewfinder") }
                Button { showSearch = true } label: { Label("Search food", systemImage: "magnifyingglass") }
                soon("Log exercise", "figure.run")
                soon("Log weight", "scalemass")
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .fullScreenCover(item: $glassesMode, onDismiss: { dismiss() }) { mode in
                GlassesModeView(useGlasses: mode == .glasses)
            }
            .sheet(isPresented: $showPhoto) {
                PhotoScanSheet(meal: meal, date: Date(), onLogged: { dismiss() })
            }
            .sheet(isPresented: $showBarcode) {
                BarcodeScanSheet { code in Task { await lookUp(code) } }
            }
            .sheet(isPresented: $showSearch) {
                AddFoodView(meal: meal, date: Date())
            }
            .sheet(item: $scanned) { item in
                NavigationStack {
                    FoodDetailView(item: item, meal: meal, date: Date(), source: .barcode,
                                   onLogged: { scanned = nil; dismiss() })
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { scanned = nil } } }
                }
            }
        }
    }

    private func soon(_ title: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("Coming soon").font(.footnote)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Not available yet")
    }

    private func lookUp(_ code: String) async {
        lookingUp = true
        error = nil
        lastCode = nil
        defer { lookingUp = false }
        do {
            if let product = try await Backend.shared.lookupBarcode(code).first {
                scanned = product
            } else {
                error = "No product found for barcode \(code)."
            }
        } catch {
            self.error = error.localizedDescription
            lastCode = code
        }
    }
}
