//
// Continuous voice commands with Apple Speech (on-device when supported) and AVAudioEngine. Over Bluetooth HFP the
// glasses mic and speakers are used. One recognition task per utterance: a short silence ends it, and a new task
// starts after each final result or error until pause() or stop().
//

import AVFoundation
import Speech

enum SpeechError: LocalizedError {
    case unavailable

    var errorDescription: String? { "Speech recognition isn't available right now." }
}

@MainActor
final class SpeechRecognizer {
    /// The current utterance as it is being recognized.
    var onPartial: ((String) -> Void)?

    // ponytail: the command words are English, so the recognizer is English whatever the device language.
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinal: ((String) -> Void)?
    private var tapInstalled = false
    private var listening = false
    private var paused = false
    /// Bumped whenever a task ends; callbacks from older tasks are dropped.
    private var generation = 0
    private var silenceTimer: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var routeObserver: NSObjectProtocol?
    // ponytail: fixed end-of-utterance silence; tune on device if commands get cut off or feel slow.
    private static let silence: Duration = .seconds(1)

    /// Asks for speech recognition, then microphone access; true when both are granted.
    nonisolated static func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { (done: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in done.resume(returning: status == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Starts listening; `onFinal` gets each finished utterance on the main actor.
    func start(onFinal: @escaping (String) -> Void) throws {
        endTask()
        let session = AVAudioSession.sharedInstance()
        // .allowBluetooth is HFP (renamed .allowBluetoothHFP in the iOS 26 SDK): glasses mic and speakers.
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
        self.onFinal = onFinal
        listening = true
        paused = false
        if routeObserver == nil {
            // The engine stops itself when the audio route changes (e.g. the glasses' HFP link comes up).
            routeObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.routeChanged() }
            }
        }
        do {
            try beginTask()
        } catch {
            stop()
            throw error
        }
    }

    /// Stops hearing (while the app speaks) but keeps the audio session.
    func pause() {
        paused = true
        endTask()
    }

    func resume() {
        guard listening, paused else { return }
        paused = false
        restart(after: .zero)
    }

    func stop() {
        listening = false
        paused = false
        onFinal = nil
        endTask()
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func routeChanged() {
        guard listening, !paused else { return }  // a paused recognizer reads the new format on resume
        endTask()
        restart(after: .milliseconds(300))
    }

    private func beginTask() throws {
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // A zero format (no input route) would crash installTap.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechError.unavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.contextualStrings = ["scan this", "add it", "skip", "how am I doing", "stop glasses"]
        // @Sendable: both closures run off the main thread, so they must not inherit main-actor isolation.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable (buffer, _) in
            request.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            endTask()
            throw error
        }

        let ticket = generation
        self.request = request
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] (result, error) in
            let text = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in self?.received(ticket, text: text, isFinal: isFinal, failed: failed) }
        }
    }

    private func received(_ ticket: Int, text: String, isFinal: Bool, failed: Bool) {
        guard ticket == generation else { return }  // from a task that already ended
        if !isFinal && !failed {
            if !text.isEmpty {
                onPartial?(text)
                endUtteranceAfterSilence()
            }
            return
        }
        endTask()
        if isFinal, !text.isEmpty { onFinal?(text) }
        // onFinal may have paused (the app is about to speak) or stopped listening.
        if listening, !paused { restart(after: isFinal ? .zero : .milliseconds(500)) }  // errors: no hot loop
    }

    /// After `silence` with no new words, ends the audio so the recognizer sends the final result.
    private func endUtteranceAfterSilence() {
        silenceTimer?.cancel()
        let ticket = generation
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.silence)
            guard let self, !Task.isCancelled, ticket == self.generation else { return }
            self.stopAudio()
            self.request?.endAudio()
        }
    }

    /// Starts the next task after `delay`; retries every second while that fails (e.g. the mic route is changing).
    private func restart(after delay: Duration) {
        retry?.cancel()
        retry = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, self.listening, !self.paused, self.task == nil else { return }
            do {
                try self.beginTask()
            } catch {
                self.restart(after: .seconds(1))
            }
        }
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func endTask() {
        generation += 1
        silenceTimer?.cancel()
        silenceTimer = nil
        retry?.cancel()
        retry = nil
        stopAudio()
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }
}
