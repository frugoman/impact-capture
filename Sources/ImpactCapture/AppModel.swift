import AppKit
import ImpactCaptureCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsChanged(from: oldValue)
        }
    }
    @Published private(set) var today: [StoredCapture] = []
    @Published private(set) var week: [StoredCapture] = []
    @Published private(set) var stats = CaptureStats()
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Shortcuts that couldn't be registered because another app already uses them.
    @Published private(set) var unavailableShortcuts: [String] = []

    let transcriber = SpeechTranscriber()

    private let settingsStore: SettingsStore
    private let stateStore: PromptStateStore
    private let windows = WindowManager()
    private let panel = CapturePanelController()
    private let calendar = Calendar.current
    private var store: CaptureStore
    private var hotKeys: [GlobalHotKey] = []
    private var hotKeysSuspended = false
    private lazy var triggers = TriggerEngine(
        minimumAway: { [weak self] in self?.policy.minimumAway ?? 15 * 60 },
        onTrigger: { [weak self] trigger in self?.consider(trigger) }
    )

    init(settingsStore: SettingsStore = SettingsStore(), stateStore: PromptStateStore = PromptStateStore()) {
        self.settingsStore = settingsStore
        self.stateStore = stateStore
        let settings = settingsStore.load()
        self.settings = settings
        store = CaptureStore(directory: settings.capturesFolder)
        transcriber.localeIdentifier = settings.speechLocaleIdentifier
    }

    var policy: PromptPolicy {
        PromptPolicy(settings: settings, calendar: calendar)
    }

    var isPaused: Bool {
        pausedUntil.map { $0 > Date() } ?? false
    }

    // MARK: Lifecycle

    func start() {
        refresh()
        triggers.start()
        applyHotKeys()
        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func handle(_ command: URLCommand) {
        switch command {
        case let .log(text, categoryID):
            log(text: text, categoryID: validCategory(categoryID), inputMethod: .typed, source: .raycast)
        case let .compose(voice, categoryID):
            compose(source: .raycast, voice: voice, categoryID: validCategory(categoryID))
        case .ask:
            askNow()
        }
    }

    // MARK: Captures

    @discardableResult
    func log(
        text: String,
        categoryID: String?,
        inputMethod: InputMethod,
        source: CaptureSource,
        trigger: PromptTrigger? = nil,
        question: String? = nil
    ) -> Bool {
        let capture = Capture(
            date: Date(),
            source: source,
            trigger: trigger?.identifier,
            question: question,
            text: text,
            categoryID: categoryID,
            inputMethod: inputMethod
        )
        do {
            try store.append(capture)
            refresh()
            return true
        } catch CaptureStoreError.emptyText {
            return false
        } catch {
            showError("Couldn't save your capture", error)
            return false
        }
    }

    func update(_ stored: StoredCapture, text: String, categoryID: String?) {
        do {
            try store.update(stored, text: text, categoryID: categoryID)
        } catch {
            showError("Couldn't update that capture", error)
        }
        refresh()
    }

    func delete(_ stored: StoredCapture) {
        do {
            try store.delete(stored)
        } catch {
            showError("Couldn't delete that capture", error)
        }
        refresh()
    }

    func refresh() {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let lookback = calendar.date(byAdding: .day, value: -60, to: startOfToday) ?? startOfToday

        let recent = store.captures(from: lookback, through: now)
        today = recent.filter { $0.day == startOfToday }
        week = recent.filter { $0.day >= weekStart }
        stats = StatsCalculator.stats(captures: recent, now: now, workdays: settings.workdays, calendar: calendar)
        pausedUntil = policy.isPaused(stateStore.load(), now: now) ? stateStore.load().pausedUntil : nil
    }

    func category(for id: String?) -> CaptureCategory? {
        settings.category(withID: id)
    }

    func captures(from start: Date, through end: Date) -> [StoredCapture] {
        store.captures(from: start, through: end)
    }

    func exportMarkdown(from start: Date, through end: Date) -> String {
        CaptureExporter.markdown(
            store.captures(from: start, through: end),
            categories: settings.categories,
            from: start,
            through: end,
            calendar: calendar
        )
    }

    // MARK: Check-ins

    func askNow() {
        consider(.manual)
    }

    func compose(source: CaptureSource, voice: Bool, categoryID: String? = nil) {
        if panel.isVisible {
            panel.focus()
            return
        }
        let session = CaptureSession(
            question: nil,
            trigger: nil,
            source: source,
            categoryID: categoryID,
            categories: settings.categories,
            transcriber: transcriber
        )
        present(session)
        if voice {
            session.startRecording()
        }
    }

    func consider(_ trigger: PromptTrigger) {
        let now = Date()
        guard !panel.isVisible else { return }

        let state = policy.rolledOver(stateStore.load(), now: now)
        guard
            policy.shouldPrompt(trigger, now: now, state: state, capturesToday: store.entryCount(on: now)),
            let question = QuestionBank.question(for: trigger, rotation: state.questionRotation, from: settings.questions)
        else { return }

        stateStore.save(policy.recordingShown(trigger, state: state, now: now))
        present(CaptureSession(
            question: question,
            trigger: trigger,
            source: .prompt,
            categoryID: validCategory(question.categoryID),
            categories: settings.categories,
            transcriber: transcriber
        ))
    }

    func pause(until date: Date?) {
        stateStore.save(policy.paused(stateStore.load(), until: date))
        refresh()
    }

    func pauseForAnHour() {
        pause(until: Date().addingTimeInterval(60 * 60))
    }

    func pauseUntilNextWorkday() {
        pause(until: policy.nextWorkdayStart(after: Date()))
    }

    func resume() {
        pause(until: nil)
    }

    private func present(_ session: CaptureSession) {
        session.onFinish = { [weak self, weak session] outcome in
            guard let self, let session else { return }
            self.finish(session, outcome: outcome)
        }
        panel.show(session)
    }

    private func finish(_ session: CaptureSession, outcome: CaptureSession.Outcome) {
        panel.close()

        var state = policy.rolledOver(stateStore.load(), now: Date())
        switch outcome {
        case let .saved(text, categoryID, inputMethod):
            log(
                text: text,
                categoryID: categoryID,
                inputMethod: inputMethod,
                source: session.source,
                trigger: session.trigger,
                question: session.question?.text
            )
            state = policy.recordingOutcome(.answered, state: state)
        case .declined:
            state = policy.recordingOutcome(.declined, state: state)
        case .ignored:
            // Only unanswered automatic check-ins count towards backing off.
            if let trigger = session.trigger, trigger != .manual {
                state = policy.recordingOutcome(.ignored, state: state)
            }
        }
        stateStore.save(state)
    }

    // MARK: Windows

    func showOnboarding() {
        windows.show(id: "onboarding", size: NSSize(width: 640, height: 640)) {
            OnboardingView(model: self)
        }
    }

    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        windows.close(id: "onboarding")
    }

    func showSettings() {
        windows.show(id: "settings", size: NSSize(width: 780, height: 580)) {
            SettingsView(model: self)
        }
    }

    func showExport() {
        windows.show(id: "export", size: NSSize(width: 840, height: 580)) {
            ExportView(model: self)
        }
    }

    // MARK: Folder, login, permissions

    func chooseCapturesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"
        panel.directoryURL = settings.capturesFolder.deletingLastPathComponent()
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.capturesFolderPath = url.path
        }
    }

    func revealCapturesFolder() {
        try? FileManager.default.createDirectory(at: settings.capturesFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(settings.capturesFolder)
    }

    func save(markdown: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showError("Couldn't save the export", error)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            showError("Couldn't change launch at login", error)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setHotKeysSuspended(_ suspended: Bool) {
        hotKeysSuspended = suspended
        applyHotKeys()
    }

    // MARK: Private

    private func settingsChanged(from old: AppSettings) {
        settingsStore.save(settings)
        if settings.capturesFolderPath != old.capturesFolderPath {
            store = CaptureStore(directory: settings.capturesFolder)
        }
        if settings.typingShortcut != old.typingShortcut || settings.voiceShortcut != old.voiceShortcut {
            applyHotKeys()
        }
        transcriber.localeIdentifier = settings.speechLocaleIdentifier
        refresh()
    }

    private func applyHotKeys() {
        hotKeys = []
        unavailableShortcuts = []
        guard !hotKeysSuspended else { return }

        let bindings: [(ShortcutSpec?, Bool)] = [(settings.typingShortcut, false), (settings.voiceShortcut, true)]
        for case let (shortcut?, voice) in bindings {
            if let hotKey = GlobalHotKey(shortcut: shortcut, action: { [weak self] in
                self?.compose(source: .shortcut, voice: voice)
            }) {
                hotKeys.append(hotKey)
            } else {
                unavailableShortcuts.append(shortcut.displayString)
            }
        }
    }

    private func validCategory(_ id: String?) -> String? {
        category(for: id)?.id
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

struct SettingsStore {
    private let key = "settings"
    var defaults = UserDefaults.standard

    func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save(_ settings: AppSettings) {
        defaults.set(try? JSONEncoder().encode(settings), forKey: key)
    }
}

struct PromptStateStore {
    private let key = "promptState"
    var defaults = UserDefaults.standard

    func load() -> PromptState {
        guard
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(PromptState.self, from: data)
        else { return PromptState() }
        return state
    }

    func save(_ state: PromptState) {
        defaults.set(try? JSONEncoder().encode(state), forKey: key)
    }
}
