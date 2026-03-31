//
// On-device speech using Apple Speech framework + AVAudioEngine (glasses mic when routed over Bluetooth HFP).
//

import AVFoundation
import Foundation
import Speech

@MainActor
final class OnDeviceSpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var partialText: String = ""
    @Published var isListening: Bool = false
    @Published var onDeviceAvailable: Bool = false

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private var hasTapInstalled = false

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        onDeviceAvailable = speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    func prepareBluetoothAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func resetAudioSession() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening(appendToTranscript: String) throws {
        stopListening()
        transcript = appendToTranscript
        partialText = ""

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        recognitionTask =
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        let text = result.bestTranscription.formattedString
                        self.partialText = text
                        if result.isFinal {
                            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !line.isEmpty {
                                if self.transcript.isEmpty {
                                    self.transcript = line
                                } else {
                                    self.transcript += "\n" + line
                                }
                            }
                            self.partialText = ""
                            self.stopListening()
                        }
                    }
                    if error != nil {
                        self.stopListening()
                    }
                }
            }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        partialText = ""
    }
}
