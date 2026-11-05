//
// The phone's back camera as a CameraSource: live preview layer, food barcodes from AVCaptureMetadataOutput,
// and full-size stills from AVCapturePhotoOutput.
//

import AVFoundation
import UIKit

@MainActor
final class PhoneCameraSession: NSObject, CameraSource {
    /// The last captured photo; the live picture is `previewLayer`.
    private(set) var latestFrame: UIImage?
    var onBarcode: ((String) -> Void)?
    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    /// Shared by every instance, so a closing screen's stopRunning can't race the next screen's startRunning.
    private static let queue = DispatchQueue(label: "PhoneCameraSession")
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false
    private var isStarting = false
    /// Bumped by stop(); a start() that sees it change after an await has been cancelled.
    private var generation = 0
    private var barcodes = BarcodeDebounce()
    private var photoWaiter: CheckedContinuation<UIImage?, Never>?

    func start() async throws {
        guard !isStarting else { return }  // a first-run start is still configuring
        isStarting = true
        let ticket = generation
        defer { if ticket == generation { isStarting = false } }
        if !isConfigured { try await configure() }
        guard ticket == generation else { throw CancellationError() }  // stopped during the permission prompt
        let session = self.session
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            Self.queue.async {
                session.startRunning()  // blocks, so never on the main thread
                done.resume()
            }
        }
        // A stop() during startRunning queued stopRunning behind it, so the camera ends up stopped.
        guard ticket == generation else { throw CancellationError() }
    }

    func stop() {
        generation += 1  // cancels a start() in progress
        isStarting = false
        let session = self.session
        Self.queue.async { session.stopRunning() }
        finishCapture(nil)
    }

    func capturePhoto() async -> UIImage? {
        // AVCapturePhotoOutput raises an exception without an active video connection.
        guard photoWaiter == nil, let connection = photoOutput.connection(with: .video),
              connection.isActive, connection.isEnabled
        else { return nil }
        let image: UIImage? = await withCheckedContinuation { continuation in
            photoWaiter = continuation
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
        if let image { latestFrame = image }
        return image
    }

    private func configure() async throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraSourceError.phoneCameraUnavailable  // e.g. the simulator
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraSourceError.phoneCameraDenied }
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(photoOutput), session.canAddOutput(metadataOutput)
        else { throw CameraSourceError.phoneCameraUnavailable }

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        session.addOutput(photoOutput)
        session.addOutput(metadataOutput)
        session.commitConfiguration()

        // Types are only available once the output is attached; setting an unavailable one raises an exception.
        let wanted: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .code128]
        let available = metadataOutput.availableMetadataObjectTypes
        metadataOutput.metadataObjectTypes = wanted.filter { available.contains($0) }
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90  // portrait stills
        }
        isConfigured = true
    }

    private func finishCapture(_ image: UIImage?) {
        photoWaiter?.resume(returning: image)
        photoWaiter = nil
    }

    private func barcodeSeen(_ payload: String) {
        if barcodes.isNew(payload) { onBarcode?(payload) }
    }
}

extension PhoneCameraSession: AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        Task { @MainActor in self.finishCapture(image) }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection
    ) {
        let payloads = metadataObjects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        guard let payload = payloads.first(where: { !$0.isEmpty }) else { return }
        Task { @MainActor in self.barcodeSeen(payload) }
    }
}
