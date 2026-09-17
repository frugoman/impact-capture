import AppKit
import CoreGraphics
import ImpactCaptureCore

/// Watches for natural break points: coming back to the Mac after being away, and the end of the day.
/// It only reports moments; `PromptPolicy` decides whether they're worth an interruption.
@MainActor
final class TriggerEngine {
    private let minimumAway: () -> TimeInterval
    private let onTrigger: (PromptTrigger) -> Void
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lockedAt: Date?
    private var lastIdle: TimeInterval = 0

    init(minimumAway: @escaping () -> TimeInterval, onTrigger: @escaping (PromptTrigger) -> Void) {
        self.minimumAway = minimumAway
        self.onTrigger = onTrigger
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.markAway() }
        })
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.markBack() }
        })
    }

    private func markAway() {
        if lockedAt == nil {
            lockedAt = Date()
        }
    }

    private func markBack() {
        guard let lockedAt else { return }
        self.lockedAt = nil
        let away = max(Date().timeIntervalSince(lockedAt), lastIdle)
        lastIdle = 0
        onTrigger(.awayReturn(away: away))
    }

    private func tick() {
        let idle = Self.secondsSinceLastInput()
        // Idle time dropping means the user touched the Mac again without having locked it.
        if lockedAt == nil, idle < lastIdle, lastIdle >= minimumAway() {
            onTrigger(.awayReturn(away: lastIdle))
        }
        lastIdle = idle
        onTrigger(.endOfDay)
    }

    private static func secondsSinceLastInput() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}
