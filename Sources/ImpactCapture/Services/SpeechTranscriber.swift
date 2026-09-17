import AVFoundation
import Speech

/// On-device dictation. The microphone is only open between `start` and `stop`.
@MainActor
final class SpeechTranscriber: ObservableObject {
    enum PermissionState {
        case notDetermined
        case granted
        case denied
    }

    @Published private(set) var isRecording = false
    @Published private(set) var errorMessage: String?

    var localeIdentifier = "en-US"

    static var permissionState: PermissionState {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        if speech == .authorized && microphone == .authorized {
            return .granted
        }
        if [.denied, .restricted].contains(speech) || [.denied, .restricted].contains(microphone) {
            return .denied
        }
        return .notDetermined
    }

    static var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales()
            .sorted { displayName(for: $0) < displayName(for: $1) }
    }

    static func displayName(for locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onTranscript: ((String) -> Void)?
    private var stopCompletion: (() -> Void)?
    private var sessionID = UUID()

    func start(onTranscript: @escaping (String) -> Void) {
        guard !isRecording else { return }
        errorMessage = nil
        Task {
            guard await Self.requestPermissions() else {
                errorMessage = "Microphone or speech recognition access is off. "
                    + "Turn it on in System Settings › Privacy & Security."
                return
            }
            begin(onTranscript: onTranscript)
        }
    }

    /// Stops listening and calls `completion` once the final transcript has been delivered.
    func stop(completion: (() -> Void)? = nil) {
        guard isRecording else {
            completion?()
            return
        }
        stopCompletion = completion
        stopEngine()
        request?.endAudio()

        let id = sessionID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.sessionID == id else { return }
            self.finish()
        }
    }

    func cancel() {
        onTranscript = nil
        stopCompletion = nil
        task?.cancel()
        stopEngine()
        finish()
    }

    private func begin(onTranscript: @escaping (String) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. You can still type."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            return
        }

        let id = UUID()
        sessionID = id
        self.request = request
        self.onTranscript = onTranscript
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isDone = result?.isFinal == true || error != nil
            DispatchQueue.main.async {
                guard let self, self.sessionID == id else { return }
                if let text {
                    self.onTranscript?(text)
                }
                if isDone {
                    self.finish()
                }
            }
        }
    }

    private func stopEngine() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
    }

    private func finish() {
        stopEngine()
        sessionID = UUID()
        isRecording = false
        task = nil
        request = nil
        onTranscript = nil
        let completion = stopCompletion
        stopCompletion = nil
        completion?()
    }

    static func requestPermissions() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }
}
