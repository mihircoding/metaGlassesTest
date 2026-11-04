//
// Meta glasses camera on DAT SDK 1.0: live frames, Vision food-barcode detection, and photo capture that
// falls back to the latest frame after 3 s. SDK calls mirror Meta's CameraAccess sample (CameraViewModel.swift).
//

import MWDATCamera
import MWDATCore
import Observation
import UIKit
import Vision

@Observable
@MainActor
final class GlassesSession: CameraSource {
    private(set) var latestFrame: UIImage? = nil
    var onBarcode: ((String) -> Void)? = nil
    /// Called once when the session or stream stops after `start()` succeeded (glasses folded, off or out of range).
    var onDisconnect: (() -> Void)? = nil

    // Made up front: AutoDeviceSelector fills in from devicesStream() asynchronously, so one created
    // right before createSession can still be empty (Meta AGENTS.md; the CameraAccess sample does the same).
    private let deviceSelector = AutoDeviceSelector(wearables: Wearables.shared)
    private let tokens = ListenerTokenBag()
    private var session: DeviceSession? = nil
    private var camera: MWDATCamera.Camera? = nil
    private var isLive = false
    private var streamWasUp = false
    private var visionBusy = false
    private var lastVisionAt = Date.distantPast
    private var barcodes = BarcodeDebounce()
    private var photoWaiter: CheckedContinuation<UIImage?, Never>? = nil
    private var photoTimeout: Task<Void, Never>? = nil

    func start() async throws {
        guard session == nil else { return }
        let wearables = Wearables.shared
        guard wearables.registrationState == .registered else { throw CameraSourceError.glassesNotConnected }

        // The check throws when no glasses are on the link, so an error means "not connected", not "denied".
        var permission = try? await wearables.checkPermissionStatus(.camera)
        if permission == .denied {
            permission = try? await wearables.requestPermission(.camera)  // switches to Meta AI and back
        }
        guard permission != nil else { throw CameraSourceError.glassesNotConnected }
        guard permission == .granted else { throw CameraSourceError.glassesCameraDenied }

        guard let newSession = try? wearables.createSession(deviceSelector: deviceSelector) else {
            throw CameraSourceError.glassesNotConnected
        }
        session = newSession
        // Subscribe before start() so no transition is missed.
        newSession.statePublisher.listen { [weak self] state in
            Task { @MainActor in self?.sessionStateChanged(state) }
        }.store(in: tokens)
        do {
            try newSession.start()
        } catch {
            stop()
            throw CameraSourceError.glassesNotConnected
        }

        // addCamera needs a started session. A failed start ends in .stopped; stop() during the wait clears `session`.
        let deadline = Date().addingTimeInterval(15)
        while newSession.state != .started, newSession.state != .stopped, session != nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        let config = StreamConfiguration(videoCodec: .raw, resolution: .low, frameRate: 15)
        guard newSession.state == .started, session != nil,
              let newCamera = try? newSession.addCamera(config: config)
        else {
            stop()
            throw CameraSourceError.glassesNotConnected
        }
        camera = newCamera

        let stream = newCamera.stream
        stream.statePublisher.listen { [weak self] state in
            Task { @MainActor in self?.streamStateChanged(state) }
        }.store(in: tokens)
        stream.videoFramePublisher.listen { [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            Task { @MainActor in self?.frameArrived(image) }
        }.store(in: tokens)
        stream.photoDataPublisher.listen { [weak self] photo in
            let image = UIImage(data: photo.data)
            Task { @MainActor in self?.finishCapture(image ?? self?.latestFrame) }
        }.store(in: tokens)
        stream.errorPublisher.listen { [weak self] error in
            guard case .photoCaptureFailed = error else { return }  // other errors end in a .stopped state
            Task { @MainActor in self?.finishCapture(self?.latestFrame) }
        }.store(in: tokens)
        stream.start()
        isLive = true
    }

    func stop() {
        isLive = false
        streamWasUp = false
        tokens.clear()
        session?.stop()  // cascades to the camera and its stream
        session = nil
        camera = nil
        latestFrame = nil
        finishCapture(nil)
    }

    /// Asks the glasses for a full-size JPEG; falls back to the latest frame if none arrives within 3 s.
    func capturePhoto() async -> UIImage? {
        guard let stream = camera?.stream, photoWaiter == nil else { return latestFrame }
        return await withCheckedContinuation { continuation in
            photoWaiter = continuation
            guard stream.capturePhoto(format: .jpeg) else {
                finishCapture(latestFrame)  // capture didn't start, so no photo will arrive
                return
            }
            photoTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.finishCapture(self?.latestFrame)
            }
        }
    }

    private func finishCapture(_ image: UIImage?) {
        photoTimeout?.cancel()
        photoTimeout = nil
        photoWaiter?.resume(returning: image)
        photoWaiter = nil
    }

    private func sessionStateChanged(_ state: DeviceSessionState) {
        if state == .stopped { disconnected() }
    }

    private func streamStateChanged(_ state: StreamState) {
        guard isLive else { return }
        // A stream is born .stopped; only a stop after it came up means the camera went away.
        if state != .stopped {
            streamWasUp = true
        } else if streamWasUp {
            disconnected()
        }
    }

    private func disconnected() {
        guard isLive else { return }  // failures during start() are thrown, not reported here
        stop()
        onDisconnect?()
    }

    private func frameArrived(_ image: UIImage) {
        guard isLive else { return }
        latestFrame = image
        let now = Date()
        guard !visionBusy, now.timeIntervalSince(lastVisionAt) >= 0.35, let cgImage = image.cgImage else { return }
        visionBusy = true
        lastVisionAt = now
        Task.detached(priority: .userInitiated) { [weak self] in
            let payload = detectBarcode(in: cgImage)
            await self?.barcodeScanned(payload)
        }
    }

    private func barcodeScanned(_ payload: String?) {
        visionBusy = false
        guard isLive, let payload, barcodes.isNew(payload) else { return }
        onBarcode?(payload)
    }
}

/// First food barcode (EAN-8/13, UPC-E, Code 128) in the image. Synchronous; run it off the main thread.
private func detectBarcode(in image: CGImage) -> String? {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.ean8, .ean13, .upce, .code128]
    try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return request.results?.lazy.compactMap(\.payloadStringValue).first(where: { !$0.isEmpty })
}
