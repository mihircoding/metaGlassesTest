import SwiftUI
import AVFoundation
import Vision
import MWDATCamera
import MWDATCore

// MARK: - Scan Hub View

struct ScanView: View {
    @ObservedObject var wearablesVM: WearablesViewModel
    @EnvironmentObject var nutrition: NutritionViewModel
    @State private var scanMode: ScanMode = .none
    @State private var showMealTypePicker = false

    enum ScanMode { case none, barcode, glassesAI, manualSearch }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode selector cards
                    VStack(spacing: 14) {
                        ScanOptionCard(
                            icon: "eyeglasses",
                            title: "Meta Glasses AI Scan",
                            subtitle: "Point your glasses at food — AI identifies & estimates nutrition",
                            color: .purple,
                            isActive: scanMode == .glassesAI
                        ) { scanMode = .glassesAI }

                        ScanOptionCard(
                            icon: "barcode.viewfinder",
                            title: "Barcode Scanner",
                            subtitle: "Scan any food barcode to look up exact nutrition facts",
                            color: .blue,
                            isActive: scanMode == .barcode
                        ) { scanMode = .barcode }

                        ScanOptionCard(
                            icon: "magnifyingglass",
                            title: "Search Food",
                            subtitle: "Search our database of millions of foods",
                            color: .orange,
                            isActive: scanMode == .manualSearch
                        ) { scanMode = .manualSearch }
                    }
                    .padding(.horizontal)

                    // Active scan panel
                    Group {
                        switch scanMode {
                        case .glassesAI:
                            GlassesFoodScanPanel(wearablesVM: wearablesVM)
                        case .barcode:
                            BarcodeScanPanel(wearablesVM: wearablesVM)
                        case .manualSearch:
                            ManualFoodSearchPanel()
                        case .none:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)

                    // Pending entry confirmation
                    if let entry = nutrition.pendingEntry {
                        PendingEntryCard(entry: entry) {
                            showMealTypePicker = true
                        } onDismiss: {
                            nutrition.pendingEntry = nil
                            nutrition.scannedEntry = nil
                            nutrition.aiScanResult = nil
                        }
                        .padding(.horizontal)
                    }

                    // Error display
                    if let error = nutrition.scanError {
                        ErrorBanner(message: error) {
                            nutrition.scanError = nil
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Add Food")
        }
        .sheet(isPresented: $showMealTypePicker) {
            MealTypePickerSheet { mealType in
                nutrition.confirmPendingEntry(mealType: mealType)
                showMealTypePicker = false
            }
        }
    }
}

// MARK: - Scan Option Card

private struct ScanOptionCard: View {
    let icon: String; let title: String; let subtitle: String; let color: Color
    let isActive: Bool; let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: isActive ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isActive ? color : .secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? color : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glasses Food Scan Panel

private struct GlassesFoodScanPanel: View {
    @ObservedObject var wearablesVM: WearablesViewModel
    @EnvironmentObject var nutrition: NutritionViewModel
    @StateObject private var glassesScanner = GlassesFoodScanner()

    var body: some View {
        VStack(spacing: 16) {
            // Connection status
            HStack {
                Circle()
                    .fill(wearablesVM.devices.isEmpty ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text(wearablesVM.devices.isEmpty
                     ? "No glasses connected — register in settings"
                     : "\(wearablesVM.devices.count) glasses connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Preview or captured image
            if let image = nutrition.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if glassesScanner.isStreaming {
                GlassesCameraPreview(scanner: glassesScanner)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "eyeglasses")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Start camera to preview glasses view")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            // Controls
            HStack(spacing: 12) {
                if glassesScanner.isStreaming {
                    Button("Stop Camera") {
                        Task { await glassesScanner.stop() }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if let frame = glassesScanner.lastFrame {
                            nutrition.analyzeImage(frame)
                        }
                    } label: {
                        if nutrition.isAnalyzingFood {
                            ProgressView().tint(.white)
                        } else {
                            Label("Analyze Food", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(nutrition.isAnalyzingFood || glassesScanner.lastFrame == nil)
                } else {
                    Button {
                        Task { await glassesScanner.start() }
                    } label: {
                        Label("Start Glasses Camera", systemImage: "video.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(wearablesVM.devices.isEmpty)
                }
            }
            .frame(maxWidth: .infinity)

            if nutrition.profile.openAIKey.isEmpty {
                HStack {
                    Image(systemName: "key.fill").foregroundStyle(.orange)
                    Text("Add OpenAI API key in Profile → Settings for AI scanning")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // AI Result preview
            if let result = nutrition.aiScanResult {
                AIResultPreview(result: result)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AI Result Preview

private struct AIResultPreview: View {
    let result: AIFoodResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI Analysis", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.purple)

            Text(result.mealDescription)
                .font(.body.weight(.medium))

            if !result.foods.isEmpty {
                ForEach(result.foods) { food in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name).font(.subheadline)
                            Text(food.quantity).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(food.calories)) kcal").font(.subheadline.weight(.semibold))
                            Text("P:\(food.protein.macroString)g C:\(food.carbs.macroString)g F:\(food.fat.macroString)g")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Total").font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(Int(result.totalCalories)) kcal").font(.subheadline.weight(.bold))
                }
            }

            if !result.notes.isEmpty {
                Text(result.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Barcode Scan Panel

private struct BarcodeScanPanel: View {
    @ObservedObject var wearablesVM: WearablesViewModel
    @EnvironmentObject var nutrition: NutritionViewModel
    @StateObject private var barcodeSession = BarcodeScannerSession()
    @State private var lastBarcode: String?

    var body: some View {
        VStack(spacing: 14) {
            Text("Scan a product barcode using your Meta glasses or phone camera")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    Task { await barcodeSession.start() }
                } label: {
                    Label(barcodeSession.isScanning ? "Scanning…" : "Start Scan", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(barcodeSession.isScanning)

                if barcodeSession.isScanning {
                    Button("Stop") { Task { await barcodeSession.stop() } }
                        .buttonStyle(.bordered)
                }
            }

            if nutrition.isLoadingBarcode {
                ProgressView("Looking up product…")
            }

            if let barcode = barcodeSession.lastPayload, barcode != lastBarcode {
                HStack {
                    Image(systemName: "barcode")
                        .foregroundStyle(.blue)
                    Text(barcode)
                        .font(.caption.monospaced())
                }
                .onAppear {
                    lastBarcode = barcode
                    nutrition.handleBarcodeDetected(barcode)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Manual Food Search Panel

private struct ManualFoodSearchPanel: View {
    @EnvironmentObject var nutrition: NutritionViewModel

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search for a food…", text: $nutrition.searchQuery)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit { nutrition.performSearch() }
                    .onChange(of: nutrition.searchQuery) { nutrition.performSearch() }
                if !nutrition.searchQuery.isEmpty {
                    Button { nutrition.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if nutrition.isSearching {
                ProgressView()
            } else if !nutrition.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(nutrition.searchResults.prefix(10)) { result in
                        SearchResultRow(result: result) {
                            nutrition.pendingEntry = result.toFoodEntry()
                            nutrition.searchQuery = ""
                            nutrition.searchResults = []
                        }
                        Divider().padding(.leading, 16)
                    }
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SearchResultRow: View {
    let result: FoodSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name).font(.subheadline).lineLimit(1)
                    if let brand = result.brand {
                        Text(brand).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(result.calories)) kcal").font(.caption.weight(.semibold))
                    Text("P:\(result.protein.macroString)g").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Entry Card

private struct PendingEntryCard: View {
    let entry: FoodEntry
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ready to Log", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
            }

            Text(entry.name)
                .font(.headline)
            if let brand = entry.brand {
                Text(brand).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                NutrientBadge(value: "\(Int(entry.scaledCalories))", unit: "kcal", color: .orange)
                NutrientBadge(value: entry.scaledProtein.macroString, unit: "P", color: .blue)
                NutrientBadge(value: entry.scaledCarbs.macroString,   unit: "C", color: .orange)
                NutrientBadge(value: entry.scaledFat.macroString,     unit: "F", color: .yellow)
            }

            if let serving = entry.servingSize {
                Text("Per \(serving)").font(.caption).foregroundStyle(.secondary)
            }

            Button(action: onConfirm) {
                Label("Add to Log", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct NutrientBadge: View {
    let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String; let onDismiss: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            Text(message).font(.caption).foregroundStyle(.primary)
            Spacer()
            Button(action: onDismiss) { Image(systemName: "xmark").foregroundStyle(.secondary) }
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Meal Type Picker Sheet

struct MealTypePickerSheet: View {
    let onSelect: (FoodEntry.MealType) -> Void

    var body: some View {
        NavigationStack {
            List(FoodEntry.MealType.allCases, id: \.self) { mealType in
                Button {
                    onSelect(mealType)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mealType.icon)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.orange)
                            .clipShape(Circle())
                        Text(mealType.rawValue).font(.body)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Which meal?")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Glasses Camera Preview (wrapper around stream)

private class GlassesFoodScanner: ObservableObject {
    @Published var isStreaming = false
    @Published var lastFrame: UIImage?

    private var streamSession: StreamSession?
    private var frameToken: AnyListenerToken?

    @MainActor
    func start() async {
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        let config = StreamSessionConfig(videoCodec: .raw, resolution: .low, frameRate: 10)
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        streamSession = session

        frameToken = session.videoFramePublisher.listen { [weak self] frame in
            if let img = frame.makeUIImage() {
                Task { @MainActor in self?.lastFrame = img }
            }
        }
        isStreaming = true
        await session.start()
    }

    @MainActor
    func stop() async {
        frameToken = nil
        if let s = streamSession { await s.stop() }
        streamSession = nil
        isStreaming = false
    }
}

private struct GlassesCameraPreview: View {
    @ObservedObject var scanner: GlassesFoodScanner

    var body: some View {
        Group {
            if let frame = scanner.lastFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.overlay {
                    ProgressView().tint(.white)
                }
            }
        }
    }
}
