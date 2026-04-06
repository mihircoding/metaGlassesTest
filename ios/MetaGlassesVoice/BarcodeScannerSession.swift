//
// Streams glasses camera (MWDATCamera), detects barcodes with Vision, speaks result via AVSpeechSynthesizer.
//

import AVFoundation
import MWDATCamera
import MWDATCore
import UIKit
import Vision

@MainActor
final class BarcodeScannerSession: ObservableObject {
    @Published var lastPayload: String?
    @Published var lastSymbologyLabel: String?
    @Published var isScanning = false

    private let wearables: WearablesInterface
    private var streamSession: StreamSession?
    private var frameToken: AnyListenerToken?
    private let speechSynth = AVSpeechSynthesizer()

    private var lastVisionAt = Date.distantPast
    private var visionBusy = false
    private var lastAnnouncedPayload: String?
    private var lastAnnouncedAt = Date.distantPast

    init(wearables: WearablesInterface = Wearables.shared) {
        self.wearables = wearables
    }

    func start() async {
        await stopInternal()
        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: StreamingResolution.low,
            frameRate: 15,
        )
        let session = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
        streamSession = session
        isScanning = true

        frameToken = session.videoFramePublisher.listen { [weak self] videoFrame in
            guard let self else { return }
            Task { @MainActor in
                self.handleVideoFrame(videoFrame)
            }
        }

        await session.start()
    }

    func stop() async {
        await stopInternal()
    }

    private func stopInternal() async {
        frameToken = nil
        if let s = streamSession {
            await s.stop()
        }
        streamSession = nil
        isScanning = false
        visionBusy = false
    }

    private func handleVideoFrame(_ frame: VideoFrame) {
        let now = Date()
        if now.timeIntervalSince(lastVisionAt) < 0.35 || visionBusy { return }
        lastVisionAt = now
        guard let uiImage = frame.makeUIImage(), let cgImage = uiImage.cgImage else { return }

        visionBusy = true
        let request = VNDetectBarcodesRequest { [weak self] req, _ in
            defer {
                Task { @MainActor in
                    self?.visionBusy = false
                }
            }
            guard
                let self,
                let results = req.results as? [VNBarcodeObservation],
                let first = results.first,
                let payload = first.payloadStringValue,
                !payload.isEmpty
            else { return }

            let label = String(describing: first.symbology)
            Task { @MainActor in
                self.onBarcodeDetected(payload: payload, symbologyLabel: label)
            }
        }

        if #available(iOS 15.0, *) {
            request.symbologies = [
                .qr, .ean13, .ean8, .code128, .code39, .code93, .pdf417, .aztec, .dataMatrix, .upce, .itf14, .codabar,
            ]
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    self?.visionBusy = false
                }
            }
        }
    }

    private func onBarcodeDetected(payload: String, symbologyLabel: String) {
        let now = Date()
        if payload == lastAnnouncedPayload, now.timeIntervalSince(lastAnnouncedAt) < 5 {
            return
        }
        lastAnnouncedPayload = payload
        lastAnnouncedAt = now
        lastPayload = payload
        lastSymbologyLabel = symbologyLabel

        let utterance = AVSpeechUtterance(string: "Scanned \(symbologyLabel). The value is \(payload).")
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        speechSynth.speak(utterance)
    }
}
