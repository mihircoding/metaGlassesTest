import NutraCore
import SwiftUI
import UIKit

/// Camera -> analyze-food -> ScanResultCard -> one food_logs row per item.
struct PhotoScanSheet: View {
    let meal: Meal
    let date: Date
    var onLogged: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case capture, analyzing, result, failed(String) }
    @State private var phase = Phase.capture
    @State private var jpeg: Data?
    @State private var items: [AnalyzedItem] = []
    @State private var notes = ""
    @State private var scanId = UUID()
    @State private var saveError: String?
    @State private var lastMeal: Meal?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .capture:
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        CameraPicker(onImage: analyze, onCancel: { dismiss() }).ignoresSafeArea()
                    } else {
                        failure("The camera isn't available on this device.", canRetry: false)
                    }
                case .analyzing:
                    ProgressView("Analyzing your food...")
                case .result:
                    ScrollView {
                        if !notes.isEmpty {
                            Text(notes).font(.footnote).foregroundStyle(.secondary).padding([.horizontal, .top])
                        }
                        ScanResultCard(items: $items, onAdd: { add($0) }, onSkip: { dismiss() })
                        if let saveError {
                            VStack(spacing: 8) {
                                Text(saveError).foregroundStyle(Theme.bad).font(.footnote)
                                Button("Retry") { if let lastMeal { add(lastMeal) } }.buttonStyle(.bordered)
                            }
                        }
                    }
                    .disabled(saving)
                case .failed(let message):
                    failure(message, canRetry: jpeg != nil)
                }
            }
            .navigationTitle("Photo scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func failure(_ message: String, canRetry: Bool) -> some View {
        VStack(spacing: 12) {
            Text(message).multilineTextAlignment(.center).foregroundStyle(Theme.bad)
            if canRetry { Button("Retry") { runAnalysis() }.buttonStyle(.borderedProminent).tint(Theme.accent) }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Retake") { phase = .capture }.buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private func analyze(_ image: UIImage) {
        guard let data = ImagePrep.jpegForUpload(image) else {
            phase = .failed("Couldn't read that photo. Try again.")
            return
        }
        jpeg = data
        runAnalysis()
    }

    private func runAnalysis() {
        guard let jpeg else { return }
        phase = .analyzing
        Task {
            do {
                let result = try await Backend.shared.analyzePhoto(jpeg: jpeg)
                if result.isFood && !result.items.isEmpty {
                    items = result.items
                    notes = result.notes
                    scanId = UUID()
                    phase = .result
                } else {
                    phase = .failed(result.notes.isEmpty ? "No food found in that photo." : result.notes)
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func add(_ meal: Meal) {
        guard let userId = Backend.shared.userId, !saving else { return }
        lastMeal = meal
        saving = true
        saveError = nil
        let rows = items.map {
            FoodLogRow(analyzed: $0, userId: userId, date: date, meal: meal, source: .photoAI, scanId: scanId)
        }
        Task {
            defer { saving = false }
            do {
                try await app.addLogs(rows)
                onLogged()
                dismiss()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) } else { onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}
