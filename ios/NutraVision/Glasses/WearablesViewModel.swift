//
// DAT registration, device list, and wearable camera permission (required for devices to appear).
//

import MWDATCore
import Observation
import SwiftUI

@Observable
@MainActor
final class WearablesViewModel {
    private(set) var devices: [DeviceIdentifier] = []
    private(set) var registrationState: RegistrationState
    var isErrorPresented: Bool = false
    var errorMessage: String = ""

    private let wearables: WearablesInterface
    @ObservationIgnored private var registrationTask: Task<Void, Never>?
    @ObservationIgnored private var deviceStreamTask: Task<Void, Never>?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.registrationState = wearables.registrationState
        self.devices = wearables.devices

        registrationTask = Task {
            for await state in wearables.registrationStateStream() {
                self.registrationState = state
            }
        }

        deviceStreamTask = Task {
            for await list in wearables.devicesStream() {
                self.devices = list
            }
        }
    }

    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }

    func connectGlasses() {
        guard registrationState != .registering else { return }
        Task {
            do {
                try await wearables.startRegistration()
            } catch let error as RegistrationError {
                presentError(error.description)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func disconnectGlasses() {
        Task {
            do {
                try await wearables.startUnregistration()
            } catch let error as UnregistrationError {
                presentError(error.description)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    /// Meta documents that `devicesStream` may stay empty until at least one wearable permission (e.g. camera) is granted via Meta AI.
    func requestWearableCameraPermission() async {
        let permission = Permission.camera
        do {
            let status = try await wearables.checkPermissionStatus(permission)
            if status == .granted { return }
            _ = try await wearables.requestPermission(permission)
        } catch {
            presentError("Wearable permission: \(error.localizedDescription)")
        }
    }

    func presentError(_ message: String) {
        errorMessage = message
        isErrorPresented = true
    }

    func dismissError() {
        isErrorPresented = false
    }
}
