#if DEBUG
import Foundation
import OSLog

/// Debug builds only: logs whenever the main thread fails to run a queued block within a second,
/// so a frozen UI shows up in the unified log with how long it lasted.
enum MainThreadWatchdog {
    static func start() {
        let thread = Thread {
            while true {
                let ran = DispatchSemaphore(value: 0)
                let sent = Date()
                DispatchQueue.main.async { ran.signal() }
                if ran.wait(timeout: .now() + 1) == .timedOut {
                    startupLog.error("main thread blocked for over 1s")
                    ran.wait()
                    startupLog.error("main thread unblocked after \(Date().timeIntervalSince(sent), format: .fixed(precision: 1))s")
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        thread.name = "MainThreadWatchdog"
        thread.start()
    }
}
#endif
