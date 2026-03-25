//
//  SystemShortcutChecker.swift
//  Default Tamer
//
//  Checks whether a recorded shortcut combo conflicts with macOS system shortcuts
//  (from ~/Library/Preferences/com.apple.symbolichotkeys.plist) or with universally
//  used application shortcuts (⌘C, ⌘Q, etc.).
//

import AppKit

enum SystemShortcutChecker {

    // MARK: - Public API

    /// Returns a human-readable name of the conflicting shortcut, or nil if no conflict found.
    /// `keyCode` is the NSEvent key code (nil for modifier-only combos).
    /// `modifiers` is NSEvent.ModifierFlags.rawValue.
    static func conflictName(keyCode: Int?, modifiers: Int) -> String? {
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
            .intersection([.command, .option, .shift, .control])

        if let name = symbolicHotkeyConflict(keyCode: keyCode, nsFlags: nsFlags) {
            return name
        }
        if let name = universalAppShortcutConflict(keyCode: keyCode, nsFlags: nsFlags) {
            return name
        }
        return nil
    }

    // MARK: - System Symbolic Hotkeys

    /// Maps well-known symbolichotkeys action IDs to human-readable names.
    private static let knownActions: [Int: String] = [
        7:   "All Windows (Exposé)",
        8:   "Application Windows (Exposé)",
        9:   "Show Desktop",
        10:  "Screenshot",
        11:  "Screenshot to Clipboard",
        12:  "Screenshot Selection",
        13:  "Screenshot Selection to Clipboard",
        15:  "Spotlight Search",
        17:  "Spotlight Window",
        19:  "Accessibility Controls",
        20:  "Mission Control",
        23:  "Application Exposé",
        25:  "Notification Center",
        26:  "Launchpad",
        28:  "Move Left a Space",
        29:  "Move Right a Space",
        57:  "Focus Menu Bar",
        59:  "Focus the Dock",
        60:  "Focus Active Window",
        79:  "Help Menu",
        160: "Change Input Source",
        161: "Next Input Source",
        162: "Previous Input Source",
        163: "Screenshot Options",
    ]

    private static func symbolicHotkeyConflict(keyCode: Int?, nsFlags: NSEvent.ModifierFlags) -> String? {
        guard let prefsURL = prefsURL,
              let plist = NSDictionary(contentsOf: prefsURL),
              let hotkeys = plist["AppleSymbolicHotKeys"] as? [String: Any] else {
            return nil
        }

        for (actionIdStr, value) in hotkeys {
            guard let actionId = Int(actionIdStr),
                  let name = knownActions[actionId],
                  let dict = value as? [String: Any],
                  let enabled = dict["enabled"] as? Bool, enabled,
                  let valueDict = dict["value"] as? [String: Any],
                  let params = valueDict["parameters"] as? [Any],
                  params.count >= 3,
                  let carbonKey = params[1] as? Int,
                  let carbonMods = params[2] as? Int else { continue }

            let sysFlags = carbonToNSFlags(carbonMods)
                .intersection([.command, .option, .shift, .control])
            guard sysFlags == nsFlags else { continue }

            if let kc = keyCode {
                // Modifier + key: key codes must also match
                if carbonKey == kc { return name }
            } else {
                // Modifier-only: conflict only if the system shortcut also has no key (keyCode 65535)
                if carbonKey == 65535 { return name }
            }
        }
        return nil
    }

    // MARK: - Universal App Shortcuts

    // Tuples of (NSEvent keyCode, NSEvent.ModifierFlags, display name).
    // Since shortcuts now require both ⌘ and ⌥, only ⌘⌥ system combos are reachable.
    private static let universalShortcuts: [(Int, NSEvent.ModifierFlags, String)] = {
        let cmdOpt: NSEvent.ModifierFlags       = [.command, .option]
        let cmdOptShift: NSEvent.ModifierFlags  = [.command, .option, .shift]
        return [
            (4,  cmdOpt,      "Hide Others (⌘⌥H)"),
            (32, cmdOpt,      "Show/Hide Dock (⌘⌥D)"),
            (8,  cmdOpt,      "Emoji & Symbols (⌘⌥Space on some layouts)"),
            (8,  cmdOptShift, "Paste and Match Style (⌘⌥⇧V)"),
        ]
    }()

    private static func universalAppShortcutConflict(keyCode: Int?, nsFlags: NSEvent.ModifierFlags) -> String? {
        guard let kc = keyCode else { return nil }
        for (shortcutKey, shortcutFlags, name) in universalShortcuts {
            if shortcutKey == kc && shortcutFlags == nsFlags { return name }
        }
        return nil
    }

    // MARK: - Helpers

    private static var prefsURL: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Preferences/com.apple.symbolichotkeys.plist")
    }

    /// Converts a Carbon modifier bitmask (from symbolichotkeys.plist) to NSEvent.ModifierFlags.
    private static func carbonToNSFlags(_ carbon: Int) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if carbon & 0x0100 != 0 { flags.insert(.command) }
        if carbon & 0x0200 != 0 { flags.insert(.shift) }
        if carbon & 0x0800 != 0 { flags.insert(.option) }
        if carbon & 0x1000 != 0 { flags.insert(.control) }
        return flags
    }
}
