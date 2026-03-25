//
//  ShortcutRecorderView.swift
//  Default Tamer
//
//  A compact SwiftUI control that captures a modifier-key combo.
//  Click to begin recording; hold modifier keys (⌘ ⌥ ⌃ ⇧), then release — the combo is saved.
//  Esc cancels; Delete/Backspace clears the saved shortcut.
//

import SwiftUI
import AppKit

// MARK: - ShortcutRecorderView

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int?
    @Binding var modifiers: Int?

    func makeNSView(context: Context) -> ShortcutField {
        let field = ShortcutField()
        field.coordinator = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        updateLabel(field, keyCode: keyCode, modifiers: modifiers)
        return field
    }

    func updateNSView(_ field: ShortcutField, context: Context) {
        if !field.isRecording {
            updateLabel(field, keyCode: keyCode, modifiers: modifiers)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func updateLabel(_ field: ShortcutField, keyCode: Int?, modifiers: Int?) {
        field.stringValue = ShortcutFormatter.format(keyCode: keyCode, modifiers: modifiers)
        field.textColor   = (modifiers == nil) ? .secondaryLabelColor : .labelColor
    }

    // MARK: Coordinator

    final class Coordinator {
        var parent: ShortcutRecorderView
        init(_ parent: ShortcutRecorderView) { self.parent = parent }

        func recorded(keyCode: Int?, modifiers: Int) {
            parent.keyCode   = nil   // key codes are not used in routing; always nil
            parent.modifiers = modifiers
        }

        func cleared() {
            parent.keyCode   = nil
            parent.modifiers = nil
        }
    }
}

// MARK: - ShortcutField

/// NSView-based recorder that captures modifier-key combos reliably.
/// NSView (unlike NSTextField) doesn't suppress flagsChanged events or produce
/// spurious beeps, and becomes first responder cleanly inside sheet windows.
final class ShortcutField: NSView {
    weak var coordinator: ShortcutRecorderView.Coordinator?
    private(set) var isRecording = false

    private var capturedModifiers = NSEvent.ModifierFlags()
    private var hadModifiers      = false
    private var committed         = false   // guards against double-commit
    private var flagsMonitor: Any?
    private var keyMonitor: Any?

    // MARK: Display

    private let displayLabel = NSTextField(labelWithString: "Not set")

    var stringValue: String {
        get { displayLabel.stringValue }
        set { displayLabel.stringValue = newValue }
    }
    var textColor: NSColor? {
        get { displayLabel.textColor }
        set { displayLabel.textColor = newValue }
    }

    // MARK: Init

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateBorderColor()

        displayLabel.alignment  = .center
        displayLabel.font       = .monospacedSystemFont(ofSize: 13, weight: .medium)
        displayLabel.textColor  = .secondaryLabelColor
        displayLabel.isEditable = false
        displayLabel.isSelectable = false
        displayLabel.isBordered = false
        displayLabel.drawsBackground = false
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(displayLabel)
        NSLayoutConstraint.activate([
            displayLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            displayLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            displayLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            displayLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 26) }
    override var acceptsFirstResponder: Bool { true }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        isRecording ? endRecording() : beginRecording()
    }

    // MARK: Responder-chain events (fires when we're first responder)

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { super.flagsChanged(with: event); return }
        handleFlagsChanged(event.modifierFlags)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        handleKeyDown(keyCode: event.keyCode)
    }

    // MARK: Recording lifecycle

    private func beginRecording() {
        isRecording  = true
        committed    = false
        capturedModifiers = []
        hadModifiers = false
        stringValue  = "Hold ⌘⌥ + more modifiers…"
        textColor    = .secondaryLabelColor
        updateBorderColor()

        // Become first responder so the responder-chain overrides above fire
        window?.makeFirstResponder(self)

        // Local monitors as belt-and-suspenders backup
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.handleFlagsChanged(event.modifierFlags)
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.handleKeyDown(keyCode: event.keyCode)
            return nil
        }
    }

    private func endRecording() {
        isRecording = false
        removeMonitors()
        updateBorderColor()
    }

    private func removeMonitors() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        if let m = keyMonitor   { NSEvent.removeMonitor(m); keyMonitor   = nil }
    }

    // MARK: Event handling

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        let relevant = flags.intersection([.command, .option, .shift, .control])
        if !relevant.isEmpty {
            // Track the peak combo: only expand, never shrink when keys are released
            // one at a time (there is always a slight stagger between key releases).
            if capturedModifiers.isEmpty || relevant.isSuperset(of: capturedModifiers) {
                capturedModifiers = relevant
            }
            hadModifiers = true
            stringValue = ShortcutFormatter.format(keyCode: nil, modifiers: Int(capturedModifiers.rawValue))
            textColor   = .labelColor
        } else if hadModifiers && !committed {
            // All modifiers released without a key press.
            // Require both ⌘ and ⌥ — reject anything weaker.
            guard capturedModifiers.isSuperset(of: [.command, .option]) else {
                showRejection()
                return
            }
            committed = true
            let mods  = Int(capturedModifiers.rawValue)
            endRecording()
            coordinator?.recorded(keyCode: nil, modifiers: mods)
            refreshLabel()
        }
    }

    private func handleKeyDown(keyCode: UInt16) {
        switch keyCode {
        case 53:        // Escape — cancel
            endRecording()
            refreshLabel()
        case 51, 117:   // Delete / Forward Delete — clear
            endRecording()
            coordinator?.cleared()
            refreshLabel()
        default:
            guard !committed else { return }
            // Letter/number keys are NOT in NSEvent.modifierFlags so they can’t be used
            // to distinguish shortcut rules at link-click time. Beep and stay in
            // recording mode so the user knows to use modifiers only.
            NSSound.beep()
        }
    }

    // MARK: Helpers

    /// Called when the recorded combo doesn’t meet the ⌘+⌥ requirement.
    /// Shows an inline rejection message for 1.8 s then resets without committing.
    private func showRejection() {
        endRecording()
        stringValue = "⌘ + ⌥ required"
        textColor   = .systemOrange
        layer?.borderColor = NSColor.systemOrange.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.refreshLabel()
            self?.updateBorderColor()
        }
    }

    private func updateBorderColor() {
        let base = NSColor.separatorColor
        layer?.borderColor = isRecording
            ? NSColor.controlAccentColor.cgColor
            : base.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    private func refreshLabel() {
        let mods = coordinator?.parent.modifiers
        let kc   = coordinator?.parent.keyCode
        stringValue = ShortcutFormatter.format(keyCode: kc, modifiers: mods)
        textColor   = (mods == nil) ? .secondaryLabelColor : .labelColor
    }
}

