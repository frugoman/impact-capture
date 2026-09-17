import Carbon.HIToolbox
import Foundation
import ImpactCaptureCore

/// A system-wide keyboard shortcut. Uses Carbon hot keys, which need no Accessibility permission.
final class GlobalHotKey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerRef: EventHandlerRef?
    private static var nextID: UInt32 = 1
    private static let signature = OSType(0x494D_4350) // "IMCP"

    private var hotKeyRef: EventHotKeyRef?
    private let id: UInt32

    /// Returns `nil` when the shortcut is already taken by another app.
    init?(shortcut: ShortcutSpec, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else { return nil }
        Self.actions[id] = action
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        Self.actions[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard hotKeyID.signature == GlobalHotKey.signature, let action = GlobalHotKey.actions[hotKeyID.id] else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async(execute: action)
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }
}
