import AppKit
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.claudemeterpro", category: "GlobalShortcut")

/// Registers a global keyboard shortcut (Cmd+Shift+U) to toggle the menu bar popover.
enum GlobalShortcut {
    private static var eventHandler: EventHandlerRef?
    private static var hotKeyRef: EventHotKeyRef?

    static func register() {
        // Cmd+Shift+U
        let hotKeyID = EventHotKeyID(signature: OSType(0x434D5052), id: 1) // "CMPR"
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_U)

        let regStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard regStatus == noErr else {
            // Most common cause: another app owns Cmd+Shift+U.
            logger.error("RegisterEventHotKey failed: \(regStatus, privacy: .public)")
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C function pointer — must not capture any Swift context, so
        // reference the static via its fully-qualified type name.
        let callback: EventHandlerUPP = { (_, _, _) -> OSStatus in
            GlobalShortcut.togglePopover()
            return noErr
        }

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        if handlerStatus != noErr {
            logger.error("InstallEventHandler failed: \(handlerStatus, privacy: .public)")
        }
    }

    /// Toggle the menu bar popover by synthesizing a click on the status item.
    private static func togglePopover() {
        // Walk NSApp.windows defensively — the class name of the MenuBarExtra
        // host window has changed across macOS versions, and force-casting
        // could crash on future updates.
        for window in NSApp.windows where window.className.contains("StatusBar") {
            if let button = window.contentView?.subviews.first(where: {
                $0 is NSStatusBarButton
            }) as? NSStatusBarButton {
                button.performClick(nil)
                return
            }
        }
        logger.debug("Status bar button not found — cannot toggle popover.")
    }
}
