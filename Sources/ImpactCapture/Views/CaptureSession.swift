import Foundation
import ImpactCaptureCore

/// One interaction with the check-in panel: optionally a yes/no question, then a spoken or typed answer.
@MainActor
final class CaptureSession: ObservableObject {
    enum Phase {
        case asking
        case answering
    }

    enum Outcome {
        case saved(text: String, categoryID: String?, inputMethod: InputMethod)
        case declined
        case ignored
    }

    @Published private(set) var phase: Phase
    @Published var text = ""
    @Published var categoryID: String?

    let question: Question?
    let trigger: PromptTrigger?
    let source: CaptureSource
    let categories: [CaptureCategory]
    let transcriber: SpeechTranscriber
    var onFinish: ((Outcome) -> Void)?

    private var usedVoice = false
    private var isFinished = false
    private var askingTimeout: Timer?

    init(
        question: Question?,
        trigger: PromptTrigger?,
        source: CaptureSource,
        categoryID: String?,
        categories: [CaptureCategory],
        transcriber: SpeechTranscriber
    ) {
        self.question = question
        self.trigger = trigger
        self.source = source
        self.categoryID = categoryID
        self.categories = categories
        self.transcriber = transcriber
        phase = question == nil ? .answering : .asking

        if question != nil {
            askingTimeout = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.phase == .asking else { return }
                    self.notNow()
                }
            }
        }
    }

    var prompt: String {
        switch phase {
        case .asking: return question?.text ?? ""
        case .answering: return question?.followUp ?? "What did you just do that no one wrote down?"
        }
    }

    var canSave: Bool {
        transcriber.isRecording || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func answerYes() {
        askingTimeout?.invalidate()
        phase = .answering
        startRecording()
    }

    func answerNo() {
        finish(.declined)
    }

    func notNow() {
        finish(.ignored)
    }

    func toggleRecording() {
        if transcriber.isRecording {
            transcriber.stop()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        usedVoice = true
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriber.start { [weak self] transcript in
            self?.text = prefix.isEmpty ? transcript : "\(prefix) \(transcript)"
        }
    }

    func save() {
        transcriber.stop { [weak self] in
            guard let self else { return }
            let text = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            self.finish(.saved(text: text, categoryID: self.categoryID, inputMethod: self.usedVoice ? .voice : .typed))
        }
    }

    func cancel() {
        finish(.ignored)
    }

    private func finish(_ outcome: Outcome) {
        guard !isFinished else { return }
        isFinished = true
        askingTimeout?.invalidate()
        if transcriber.isRecording {
            transcriber.cancel()
        }
        onFinish?(outcome)
    }
}
