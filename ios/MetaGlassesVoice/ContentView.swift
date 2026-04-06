//
// Simple UI: register with Meta AI, grant wearable camera permission (so devices appear), Bluetooth audio, transcribe.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var wearablesVM: WearablesViewModel
    @StateObject private var speech = OnDeviceSpeechRecognizer()
    @StateObject private var barcode = BarcodeScannerSession()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Registration: \(String(describing: wearablesVM.registrationState))")
                    Text("Devices: \(wearablesVM.devices.count)")
                    Text("On-device Speech: \(speech.onDeviceAvailable ? "supported" : "not supported on this device")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Register with Meta AI") {
                        wearablesVM.connectGlasses()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Unregister") {
                        wearablesVM.disconnectGlasses()
                    }

                    Button("Grant glasses camera permission (Meta AI)") {
                        Task { await wearablesVM.requestWearableCameraPermission() }
                    }
                    .buttonStyle(.bordered)

                    Button("Prepare Bluetooth audio session") {
                        do {
                            try speech.prepareBluetoothAudioSession()
                        } catch {
                            wearablesVM.presentError(error.localizedDescription)
                        }
                    }

                    Text("Point the glasses at a barcode. Grant camera permission first. Route Bluetooth so speech plays in the glasses.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Start barcode scan (glasses camera)") {
                        Task { await barcode.start() }
                    }
                    .disabled(barcode.isScanning)
                    .buttonStyle(.borderedProminent)

                    Button("Stop barcode scan") {
                        Task { await barcode.stop() }
                    }
                    .disabled(!barcode.isScanning)

                    if let sym = barcode.lastSymbologyLabel, let pay = barcode.lastPayload {
                        Text("Last: \(sym) — \(pay)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }

                    Button(speech.isListening ? "Stop listening" : "Start listening") {
                        Task { await toggleListen() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(speech.isListening ? .red : .accentColor)

                    if speech.isListening {
                        Text("Listening…")
                            .font(.caption)
                    }

                    HStack {
                        Text("Transcript")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            speech.transcript = ""
                        }
                        .font(.caption)
                    }

                    Text(displayText)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Meta Glasses Voice")
        }
        .alert("Error", isPresented: $wearablesVM.isErrorPresented) {
            Button("OK") { wearablesVM.dismissError() }
        } message: {
            Text(wearablesVM.errorMessage)
        }
    }

    private var displayText: String {
        let base = speech.transcript
        let partial = speech.partialText
        if partial.isEmpty { return base.isEmpty ? "(spoken text appears here)" : base }
        let combined = base.isEmpty ? partial : base + "\n" + partial
        return speech.isListening ? combined + "…" : combined
    }

    private func toggleListen() async {
        if speech.isListening {
            speech.stopListening()
            return
        }
        guard await speech.requestAuthorization() else {
            wearablesVM.presentError("Speech recognition not authorized. Enable in Settings / Privacy.")
            return
        }
        do {
            try speech.prepareBluetoothAudioSession()
            try speech.startListening(appendToTranscript: speech.transcript)
        } catch {
            wearablesVM.presentError(error.localizedDescription)
        }
    }

}
