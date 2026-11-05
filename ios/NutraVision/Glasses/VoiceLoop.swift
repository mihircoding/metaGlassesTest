//
// Glasses Mode's hands-free loop: voice commands and on-screen buttons go through VoiceFlow, and VoiceLoop carries
// out the effects (capture and analyze, barcode lookup, log, speak). Recognition pauses while the app speaks, so it
// never hears itself. Holds one pending scan, which auto-discards after 60 s.
//

import AVFoundation
import NutraCore
import Observation
import UIKit

@Observable
@MainActor
final class VoiceLoop: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var state: VoiceState = .idle
    /// What the user is saying, or last said.
    private(set) var transcript = ""
    /// What the app last said. Errors are spoken, so this shows them too.
    private(set) var reply = ""
    /// A start-up problem (permissions, camera, glasses), shown until the next start.
    private(set) var error: String?
    private(set) var isRunning = false
    /// The scan waiting for "add it" or "skip". ScanResultCard edits its grams through a binding.
    var pending: [AnalyzedItem] = []
    /// The card's meal picker; on-screen Add uses it. Reset to the time-of-day meal for each scan.
    var selectedMeal: Meal = MealSlot.meal(at: Date())
    private(set) var pendingSource: FoodSource = .glassesAI
    /// The spoken verdict; the card computes its own as grams change.
    private(set) var verdict: Verdict?
    /// Called after an exit command, to close the screen.
    @ObservationIgnored var onExit: (() -> Void)?

    let source: any CameraSource
    private let app: AppModel
    private let speech: SpeechRecognizer
    private let synth = AVSpeechSynthesizer()
    /// The utterance playing now; a finish or cancel for any other one is ignored.
    @ObservationIgnored private var utterance: AVSpeechUtterance?
    @ObservationIgnored private var scanId = UUID()
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var expiry: Task<Void, Never>?

    private static let saveFailed = "Couldn't save. Say add it to try again."
    // ponytail: fixed wait after speaking so the end of our own sentence, still in the Bluetooth buffer, isn't
    // heard as "skip"; raise it if the glasses react to "...or skip".
    private static let echoTail: Duration = .milliseconds(500)

    init(source: any CameraSource, app: AppModel) {
        self.source = source
        self.app = app
        self.speech = SpeechRecognizer()
        super.init()
        synth.delegate = self
    }

    /// Starts listening, then the camera. Safe to call again after a stop.
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        error = nil
        reply = ""
        source.onBarcode = { [weak self] code in self?.barcodeSeen(code) }
        (source as? GlassesSession)?.onDisconnect = { [weak self] in self?.disconnected() }
        speech.onPartial = { [weak self] text in self?.transcript = text }

        let allowed = await SpeechRecognizer.requestAuthorization()
        guard isRunning else { return }
        if allowed {
            do {
                try speech.start { [weak self] text in self?.heard(text) }
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            self.error = "Voice commands need Microphone and Speech Recognition access. Allow them for NutraVision in Settings."
        }

        do {
            try await source.start()
        } catch is CancellationError {
            // stop() ran while the camera was starting: the user left, nothing to report.
        } catch {
            guard isRunning else { return }
            self.error = error.localizedDescription
            let notConnected = (error as? CameraSourceError) == .glassesNotConnected
            halt(saying: notConnected ? SpokenText.glassesDisconnected : nil)
        }
    }

    /// Stops everything at once: camera, listening and speech. Call when the screen closes.
    func stop() {
        utterance = nil
        synth.stopSpeaking(at: .immediate)
        halt(saying: nil)
    }

    /// Runs a voice command or button tap through VoiceFlow and carries out its effects.
    func handle(_ command: VoiceCommand) {
        let (next, effects) = VoiceFlow.next(state, command)
        state = next
        for effect in effects {
            switch effect {
            case .captureAndAnalyze: work = Task { await captureAndAnalyze() }
            case .log(let meal):
                // Snapshot now, and keep the task out of `work`: an exit or disconnect must not empty or
                // cancel a confirmed add.
                let items = pending, origin = pendingSource, id = scanId, shownVerdict = verdict
                discard()
                Task { await log(items, origin: origin, scanId: id, verdict: shownVerdict, meal: meal) }
            case .discard: discard()
            case .speak(let text): speak(text)
            case .speakStatus: speakStatus()
            case .stop:
                stop()
                onExit?()
            }
        }
    }

    // MARK: Events

    private func heard(_ text: String) {
        transcript = text
        handle(VoiceCommand.parse(text))
    }

    private func barcodeSeen(_ code: String) {
        guard isRunning, state == .idle else { return }
        state = .analyzing  // looking up: a voice scan waits, exit still works
        work = Task { await lookUp(code) }
    }

    private func disconnected() {
        guard isRunning else { return }
        halt(saying: SpokenText.glassesDisconnected)  // `reply` shows it
    }

    /// Stops the camera and listening but lets `text` play out; the screen keeps showing the error.
    private func halt(saying text: String?) {
        isRunning = false
        work?.cancel()
        work = nil
        discard()
        state = .idle
        source.stop()
        if let text { speak(text) } else { speech.stop() }  // after speaking, doneSpeaking stops listening
    }

    // MARK: Effects

    private func captureAndAnalyze() async {
        let image = await source.capturePhoto()
        guard !Task.isCancelled, state == .analyzing else { return }
        guard let image, let jpeg = ImagePrep.jpegForUpload(image) else {
            failed(SpokenText.analyzeFailed)
            return
        }
        do {
            let result = try await Backend.shared.analyzePhoto(jpeg: jpeg)
            guard !Task.isCancelled, state == .analyzing else { return }
            if result.isFood && !result.items.isEmpty {
                present(result.items, from: source is GlassesSession ? .glassesAI : .photoAI)
            } else {
                failed(SpokenText.notFood)
            }
        } catch {
            guard !Task.isCancelled, state == .analyzing else { return }
            failed(SpokenText.analyzeFailed)
        }
    }

    private func lookUp(_ code: String) async {
        do {
            let product = try await Backend.shared.lookupBarcode(code).first
            guard !Task.isCancelled, state == .analyzing else { return }
            if let product {
                present([AnalyzedItem(product: product)], from: .barcode)
            } else {
                failed(SpokenText.productNotFound)
            }
        } catch {
            guard !Task.isCancelled, state == .analyzing else { return }
            failed(SpokenText.analyzeFailed)
        }
    }

    private func failed(_ text: String) {
        state = .idle
        speak(text)
    }

    private func present(_ items: [AnalyzedItem], from origin: FoodSource) {
        pending = items
        pendingSource = origin
        scanId = UUID()
        selectedMeal = MealSlot.meal(at: Date())
        let total = items.map(\.nutrients).sum()
        let verdict = app.verdict(name: items.map(\.name).joined(separator: ", "), item: total)
        self.verdict = verdict
        state = .awaitingConfirm
        discardAfter60s()
        speak(SpokenText.scanResult(itemNames: items.map(\.name), total: total,
                                    lowConfidence: items.contains { $0.confidence == .low },
                                    verdict: verdict, conditionName: primaryConditionName))
    }

    private func discard() {
        expiry?.cancel()
        expiry = nil
        pending = []
        verdict = nil
    }

    private func discardAfter60s() {
        expiry?.cancel()
        expiry = Task {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, state == .awaitingConfirm else { return }
            state = .idle
            discard()
        }
    }

    /// One row per item with a shared scan id, in `meal` or the time-of-day meal; then the new day total.
    /// Runs to the end even after the screen closes: a confirmed add is saved, or its failure is reported.
    private func log(_ items: [AnalyzedItem], origin: FoodSource, scanId id: UUID, verdict shownVerdict: Verdict?,
                     meal: Meal?) async {
        let slot = meal ?? selectedMeal
        do {
            guard let userId = Backend.shared.userId else { throw BackendError.message("You're signed out.") }
            let rows = items.map {
                FoodLogRow(analyzed: $0, userId: userId, date: Date(), meal: slot, source: origin, scanId: id)
            }
            try await app.addLogs(rows)  // inserts, then reloads today
            guard isRunning else { return }  // closed meanwhile: saved, and nothing is spoken after exit
            speak(SpokenText.added(consumedKcal: app.today?.consumed.kcal ?? 0, goalKcal: app.dailyGoalKcal))
        } catch {
            guard isRunning else {
                // Closed meanwhile, so nobody hears it: report it in the app-wide banner instead.
                app.banner = "Couldn't save your Glasses Mode scan: \(error.localizedDescription)"
                return
            }
            if state == .idle && pending.isEmpty {  // nothing newer arrived: offer the same scan again
                pending = items
                pendingSource = origin
                scanId = id
                verdict = shownVerdict
                selectedMeal = slot
                state = .awaitingConfirm
                discardAfter60s()
            }
            speak(Self.saveFailed)
        }
    }

    /// Calories left, plus whichever of sodium, saturated fat and carbs is closest to its limit.
    private func speakStatus() {
        let eaten = app.today?.consumed ?? .zero
        let targets = app.targets
        let limits: [(String, Double, Double)] = [("Sodium", eaten.sodiumMg, targets.sodiumMg),
                                                  ("Saturated fat", eaten.satFatG, targets.satFatG),
                                                  ("Carbs", eaten.carbsG, targets.carbsG)]
        var closest: (name: String, percent: Int)?
        var highest = 0.0
        for (name, used, limit) in limits where limit > 0 && used / limit > highest {
            highest = used / limit
            closest = (name: name, percent: Int((highest * 100).rounded()))
        }
        speak(SpokenText.status(consumedKcal: eaten.kcal, goalKcal: app.dailyGoalKcal, closestLimit: closest))
    }

    /// The primary condition's name, or nil for no condition.
    private var primaryConditionName: String? {
        guard let id = app.profile?.conditions.first else { return nil }
        let condition = ConditionCatalog.condition(id: id)
        return condition.id == "general" ? nil : condition.name
    }

    // MARK: Speaking

    private func speak(_ text: String) {
        reply = text
        speech.pause()  // so the app doesn't hear itself
        let next = AVSpeechUtterance(string: text)
        next.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance = next
        synth.stopSpeaking(at: .immediate)  // a newer sentence replaces the old one
        synth.speak(next)
    }

    private func doneSpeaking(_ id: ObjectIdentifier) {
        guard let current = utterance, ObjectIdentifier(current) == id else { return }  // an interrupted one
        utterance = nil
        guard isRunning else {
            speech.stop()
            return
        }
        Task {
            try? await Task.sleep(for: Self.echoTail)
            guard isRunning, utterance == nil else { return }  // stopped, or speaking again
            speech.resume()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.doneSpeaking(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.doneSpeaking(id) }
    }
}
