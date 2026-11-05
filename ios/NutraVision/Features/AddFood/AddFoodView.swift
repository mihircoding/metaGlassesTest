import NutraCore
import SwiftUI

/// Present as a sheet. Search | Recent | My Foods | Plan, plus barcode and photo scan.
struct AddFoodView: View {
    let meal: Meal
    let date: Date
    /// Pick mode (plan editor): foods are chosen, not logged. Photo scan is hidden.
    var onPick: ((FoodItem, Double) -> Void)? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// A food to show in a list, and how logging it is recorded.
    private struct Entry: Identifiable {
        var item: FoodItem
        var source: FoodSource
        var id: String { "\(source.rawValue)/\(item.id)" }
    }

    private enum Segment: String, CaseIterable { case search = "Search", recent = "Recent", mine = "My Foods", plan = "Plan" }

    @State private var segment = Segment.search
    @State private var query = ""
    @State private var entries: [Entry] = []
    @State private var loading = false
    @State private var error: String?
    @State private var retryTick = 0
    @State private var showBarcode = false
    @State private var showPhoto = false
    @State private var scanned: Entry?
    @State private var lookingUp = false
    /// Set while the visible error came from a barcode lookup, so Retry repeats that lookup.
    @State private var lastCode: String?
    @State private var customFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Source", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                list
            }
            .navigationTitle("Add to \(meal.title)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    if onPick == nil {
                        Button { showPhoto = true } label: { Image(systemName: "camera") }
                            .accessibilityLabel("Photo scan")
                    }
                    Button { showBarcode = true } label: { Image(systemName: "barcode.viewfinder") }
                        .accessibilityLabel("Scan barcode")
                }
            }
            .task(id: "\(segment.rawValue)|\(query)|\(retryTick)") { await load() }
            .sheet(isPresented: $showBarcode) {
                BarcodeScanSheet { code in Task { await lookUp(code) } }
            }
            .sheet(isPresented: $showPhoto) {
                PhotoScanSheet(meal: meal, date: date, onLogged: { dismiss() })
            }
            .sheet(item: $scanned) { entry in
                NavigationStack {
                    FoodDetailView(item: entry.item, meal: meal, date: date, source: entry.source,
                                   onLogged: { scanned = nil; dismiss() }, onPick: onPick)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { scanned = nil } } }
                }
            }
        }
    }

    @ViewBuilder private var list: some View {
        List {
            if segment == .mine {
                NavigationLink("Create Food") { CreateFoodView(onSaved: { retryTick += 1 }) }
            }
            if let error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).foregroundStyle(Theme.bad).font(.footnote)
                    Button("Retry") { retry() }.buttonStyle(.bordered)
                }
            } else if loading || lookingUp {
                ProgressView().frame(maxWidth: .infinity)
            } else if entries.isEmpty {
                Text(emptyText).foregroundStyle(.secondary)
            }
            if customFailed, error == nil {
                HStack {
                    Text("Couldn't load My Foods").font(.footnote).foregroundStyle(Theme.bad)
                    Spacer()
                    Button("Retry") { retryTick += 1 }.buttonStyle(.bordered)
                }
            }
            ForEach(entries) { entry in
                NavigationLink {
                    FoodDetailView(item: entry.item, meal: meal, date: date, source: entry.source,
                                   onLogged: { dismiss() }, onPick: onPick)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.item.name)
                        Text([entry.item.brand, entry.item.servingDesc, "\(Int(entry.item.perServing.kcal.rounded())) kcal"]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyText: String {
        switch segment {
        case .search: return query.trimmingCharacters(in: .whitespaces).count < 2 ? "Type at least 2 characters to search." : "No foods found."
        case .recent: return "Foods you log will show up here."
        case .mine: return "No custom foods yet."
        case .plan: return "No active diet plan. Start one from Conditions & Diet Plans."
        }
    }

    // MARK: Loading

    private func load() async {
        error = nil
        lastCode = nil
        customFailed = false
        let q = query.trimmingCharacters(in: .whitespaces)
        do {
            switch segment {
            case .search:
                guard q.count >= 2 else { entries = []; return }
                try await Task.sleep(for: .milliseconds(400))  // debounce: a newer keystroke cancels this task
                loading = true
                defer { loading = false }
                var custom: [CustomFoodRow] = []
                do {
                    custom = try await Backend.shared.customFoods(matching: q)
                } catch {
                    if Task.isCancelled { return }  // stale search, not a failure
                    customFailed = true  // still show USDA/OFF results, with a Retry note
                }
                let found = try await Backend.shared.searchFoods(query: q)
                entries = custom.map(Self.entry(custom:)) + found.map { Entry(item: $0, source: .search) }
            case .recent:
                loading = true
                defer { loading = false }
                guard let userId = Backend.shared.userId else { return }
                entries = try await Backend.shared.recentFoods(userId: userId).map(Self.entry(log:))
            case .mine:
                loading = true
                defer { loading = false }
                entries = try await Backend.shared.customFoods(matching: q).map(Self.entry(custom:))
            case .plan:
                loading = true
                defer { loading = false }
                guard let userId = Backend.shared.userId else { return }
                let plan = try await Backend.shared.dietPlans(userId: userId).first { $0.isActive }
                entries = (plan?.meals.flatMap { $0.items } ?? []).map(Self.entry(plan:))
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func lookUp(_ code: String) async {
        lookingUp = true
        lastCode = nil
        error = nil
        defer { lookingUp = false }
        do {
            if let product = try await Backend.shared.lookupBarcode(code).first {
                scanned = Entry(item: product, source: .barcode)
            } else {
                error = "No product found for barcode \(code)."
                lastCode = code
            }
        } catch {
            self.error = error.localizedDescription
            lastCode = code
        }
    }

    /// A barcode error retries the lookup; any other error reloads the current segment.
    private func retry() {
        if let code = lastCode { Task { await lookUp(code) } } else { retryTick += 1 }
    }

    // NutrientSource has no "manual" case; the placeholder only feeds FoodItem.id, and the log row records
    // its own FoodSource and source_ref.
    private static func entry(custom: CustomFoodRow) -> Entry {
        Entry(item: FoodItem(name: custom.name, brand: custom.brand, source: .usda, sourceRef: custom.id.uuidString,
                             servingDesc: custom.servingDesc, servingGrams: custom.servingGrams,
                             perServing: custom.perServing), source: .manual)
    }

    private static func entry(log: FoodLogRow) -> Entry {
        Entry(item: FoodItem(name: log.name, brand: log.brand, source: log.source == .barcode ? .off : .usda,
                             sourceRef: log.sourceRef ?? log.id.uuidString, servingDesc: log.servingDesc,
                             servingGrams: log.servingGrams, perServing: log.perServing), source: log.source)
    }

    private static func entry(plan: PlanItem) -> Entry {
        Entry(item: FoodItem(name: plan.name, brand: nil, source: .usda, sourceRef: plan.id.uuidString,
                             servingDesc: plan.servingDesc, servingGrams: plan.servingGrams,
                             perServing: plan.nutrients), source: .plan)
    }
}
