//
//  ShortcutManager.swift
//  Default Tamer
//
//  Shortcut rules work by detecting held modifier keys at URL-arrival time.
//  No Carbon event taps or accessibility permissions are needed.
//

import AppKit
import Carbon.HIToolbox

// MARK: - ShortcutFormatter

/// Converts a (keyCode, modifiers) pair to a human-readable string like "⌘⇧C".
enum ShortcutFormatter {
    /// Renders a modifier combo as symbols, e.g. "⌘⌥" or "⌘⇧K".
    /// When `keyCode` is nil (modifier-only shortcuts), returns just the modifier symbols.
    static func format(keyCode: Int?, modifiers: Int?) -> String {
        guard let modifiers else { return "Not set" }
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        let syms = modifierSymbols(flags)
        guard !syms.isEmpty else { return "Not set" }
        guard let keyCode else { return syms }
        return syms + keySymbol(keyCode: keyCode, flags: flags)
    }

    private static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func keySymbol(keyCode: Int, flags: NSEvent.ModifierFlags) -> String {
        switch keyCode {
        case kVK_Return:           return "↩"
        case kVK_Tab:              return "⇥"
        case kVK_Space:            return "Space"
        case kVK_Delete:           return "⌫"
        case kVK_ForwardDelete:    return "⌦"
        case kVK_Escape:           return "⎋"
        case kVK_LeftArrow:        return "←"
        case kVK_RightArrow:       return "→"
        case kVK_UpArrow:          return "↑"
        case kVK_DownArrow:        return "↓"
        case kVK_F1:               return "F1"
        case kVK_F2:               return "F2"
        case kVK_F3:               return "F3"
        case kVK_F4:               return "F4"
        case kVK_F5:               return "F5"
        case kVK_F6:               return "F6"
        case kVK_F7:               return "F7"
        case kVK_F8:               return "F8"
        case kVK_F9:               return "F9"
        case kVK_F10:              return "F10"
        case kVK_F11:              return "F11"
        case kVK_F12:              return "F12"
        default:
            // Create a dummy NSEvent to get the characters for this key code.
            // Shift-aware: pass the modifier flags so ⇧1 → ! etc.
            if let str = characterForKeyCode(keyCode, modifiers: flags) {
                return str.uppercased()
            }
            return "Key(\(keyCode))"
        }
    }

    private static func characterForKeyCode(_ keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String? {
        // Use TIS/UCKeyTranslate to get the character without needing a real event.
        guard let keyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var charCount = 0

        var carbonMods: UInt32 = 0
        // Note: UCKeyTranslate modifier format is different — shift is bit 1.
        if modifiers.contains(.shift) { carbonMods |= (1 << 1) }

        UCKeyTranslate(
            keyLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            carbonMods,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &charCount,
            &chars
        )

        guard charCount > 0 else { return nil }
        return String(utf16CodeUnits: Array(chars.prefix(charCount)), count: charCount)
    }
}
