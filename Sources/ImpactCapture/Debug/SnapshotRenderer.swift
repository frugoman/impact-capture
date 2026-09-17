#if DEBUG
import AppKit
import ImpactCaptureCore
import SwiftUI

/// Renders every screen to PNG with sample data, for design review without clicking through the app.
/// Usage: `ImpactCapture.app/Contents/MacOS/ImpactCapture -snapshot <output dir> [-dark]`
/// Uses a throwaway defaults suite and folder, so real settings and captures are untouched.
@MainActor
enum SnapshotRenderer {
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "-snapshot"), arguments.indices.contains(index + 1) else {
            return false
        }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let dark = arguments.contains("-dark")
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApp.appearance = appearance
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let model = makeSampleModel()
        let suffix = dark ? "-dark" : ""

        render(PopoverView(model: model, close: {}), size: NSSize(width: 400, height: 580), name: "popover\(suffix)", to: output, appearance: appearance)
        for step in 0..<4 {
            render(OnboardingView(model: model, initialStep: step), size: NSSize(width: 640, height: 640), name: "onboarding-\(step + 1)\(suffix)", to: output, appearance: appearance)
        }
        for section in SettingsView.Section.allCases {
            render(SettingsView(model: model, initialSection: section), size: NSSize(width: 780, height: 580), name: "settings-\(section.id.lowercased())\(suffix)", to: output, appearance: appearance)
        }
        render(ExportView(model: model), size: NSSize(width: 840, height: 580), name: "export\(suffix)", to: output, appearance: appearance)

        let question = QuestionBank.question(for: .awayReturn(away: 25 * 60), rotation: 0, from: model.settings.questions)
        let asking = CaptureSession(question: question, trigger: .awayReturn(away: 25 * 60), source: .prompt, categoryID: nil, categories: model.settings.categories, transcriber: model.transcriber)
        render(CaptureSessionView(session: asking), size: nil, name: "checkin-ask\(suffix)", to: output, appearance: appearance)

        let answering = CaptureSession(question: nil, trigger: nil, source: .shortcut, categoryID: "unblocking", categories: model.settings.categories, transcriber: model.transcriber)
        answering.text = "Paired with Ana on the flaky checkout test. Found a race in the mock server."
        render(CaptureSessionView(session: answering), size: nil, name: "checkin-log\(suffix)", to: output, appearance: appearance)
        return true
    }

    private static func makeSampleModel() -> AppModel {
        let suite = "impact-capture-snapshot-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)

        var settings = AppSettings()
        settings.hasCompletedOnboarding = true
        settings.capturesFolderPath = folder.path
        SettingsStore(defaults: defaults).save(settings)

        let store = CaptureStore(directory: folder)
        let calendar = Calendar.current
        let now = Date()
        let samples: [(daysAgo: Int, hour: Int, minute: Int, text: String, category: String?, question: String?, voice: Bool)] = [
            (0, 9, 40, "Coffee with Marco from Payments. Agreed to split the migration into two PRs so they can ship their part first.", "collaboration", "You were away 25 min. Did you talk to anyone about work?", true),
            (0, 11, 15, "Paired with Ana on the flaky checkout test. Found a race in the mock server.", "unblocking", nil, false),
            (0, 15, 5, "Pushed back on caching at the edge in the design review. We're measuring first.", "influence", nil, true),
            (1, 10, 30, "Walked Sam through how we slice work into tickets. He's running planning next sprint.", "mentoring", "Did you give feedback, advice or mentoring today?", false),
            (1, 17, 40, "Flagged that the SDK upgrade drops iOS 16 before Growth committed to a date.", "risk", nil, false),
            (2, 14, 0, "Data team thanked us for the event schema doc.", "recognition", nil, false),
        ]
        for sample in samples {
            let day = calendar.date(byAdding: .day, value: -sample.daysAgo, to: now) ?? now
            let date = calendar.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: day) ?? day
            try? store.append(Capture(
                date: date,
                source: sample.question == nil ? .shortcut : .prompt,
                trigger: sample.question == nil ? nil : "away-return",
                question: sample.question,
                text: sample.text,
                categoryID: sample.category,
                inputMethod: sample.voice ? .voice : .typed
            ))
        }

        let model = AppModel(settingsStore: SettingsStore(defaults: defaults), stateStore: PromptStateStore(defaults: defaults))
        model.refresh()
        return model
    }

    private static func render<V: View>(_ view: V, size: NSSize?, name: String, to directory: URL, appearance: NSAppearance?) {
        let host = NSHostingView(rootView: view)
        let frameSize = size ?? host.fittingSize
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -20000, y: -20000), size: frameSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.backgroundColor = .clear
        window.isOpaque = false
        host.frame = NSRect(origin: .zero, size: frameSize)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        }
        window.orderOut(nil)
    }
}
#endif
