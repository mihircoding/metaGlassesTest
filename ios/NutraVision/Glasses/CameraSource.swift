//
// What Glasses Mode needs from a camera: live frames, food barcodes and a full-size photo on demand.
// Implemented by GlassesSession (Meta glasses) and PhoneCameraSession (phone back camera).
//

import UIKit

@MainActor
protocol CameraSource: AnyObject {
    /// Newest glasses frame, or the last phone photo; nil until one arrives.
    var latestFrame: UIImage? { get }
    /// Food barcode payloads (EAN-8/13, UPC-E, Code 128), on the main actor. A code held in view is reported once.
    var onBarcode: ((String) -> Void)? { get set }
    func start() async throws
    func stop()
    /// A full-size still, or nil when the camera isn't running.
    func capturePhoto() async -> UIImage?
}

enum CameraSourceError: LocalizedError {
    case glassesNotConnected
    case glassesCameraDenied
    case phoneCameraDenied
    case phoneCameraUnavailable

    var errorDescription: String? {
        switch self {
        case .glassesNotConnected: return "Glasses not connected — open Meta AI and connect your glasses."
        case .glassesCameraDenied: return "Glasses camera access is off — allow it for NutraVision in the Meta AI app."
        case .phoneCameraDenied: return "Camera access is off — allow it for NutraVision in Settings."
        case .phoneCameraUnavailable: return "No camera is available on this device."
        }
    }
}

/// A payload is new unless the same one was seen in the last 5 s. Every sighting restarts the 5 s,
/// so a code that stays in view is reported once instead of again every 5 s.
struct BarcodeDebounce {
    private var lastPayload: String?
    private var lastSeen = Date.distantPast

    mutating func isNew(_ payload: String, at now: Date = Date()) -> Bool {
        defer {
            lastPayload = payload
            lastSeen = now
        }
        return payload != lastPayload || now.timeIntervalSince(lastSeen) >= 5
    }
}
