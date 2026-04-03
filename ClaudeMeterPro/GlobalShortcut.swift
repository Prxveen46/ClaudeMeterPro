import AppKit
import Carbon.HIToolbox

/// Registers a global keyboard shortcut (Cmd+Shift+U) to toggle the menu bar popover.
enum GlobalShortcut {
    private static var eventHandler: EventHandlerRef?

    static func register() {
        // Cmd+Shift+U
        let hotKeyID = EventHotKeyID(signature: OSType(0x434D5052), id: 1) // "CMPR"
        var hotKeyRef: EventHotKeyRef?

        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_U)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        // Install handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            // Simulate clicking the menu bar item to toggle the popover
            if let button = NSApp.windows.first(where: { $0.className.contains("StatusBar") })?.contentView?.subviews.first as? NSStatusBarButton {
                button.performClick(nil)
            } else {
                // Fallback: post a synthetic click on the status item
                NSApp.sendAction(#selector(NSStatusBarButton.performClick(_:)), to: nil, from: nil)
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
    }
}
