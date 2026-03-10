// DriftSettings.swift
// Centralized app preferences backed by UserDefaults.
// Uses @Observable with stored properties that sync to UserDefaults on write.

import Foundation
import Observation
import AppKit

@Observable
final class DriftSettings {

    // Suppresses didSet write-back during init
    private var isLoading = true

    // MARK: - Hotkey

    /// Whether the global hotkey is active.
    var hotkeyEnabled: Bool = true {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(hotkeyEnabled, forKey: "hotkeyEnabled") }
    }

    /// Raw value of NSEvent.ModifierFlags. Default: Hyperkey (⌃⌥⇧⌘).
    var hotkeyModifiers: UInt = NSEvent.ModifierFlags([.control, .option, .shift, .command]).rawValue {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }

    /// Virtual key code (e.g. 2 = D). Default: D.
    var hotkeyKeyCode: Int = 2 {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode") }
    }

    /// Display name for the key (e.g. "D", "Space"). Cached at capture time.
    var hotkeyKeyChar: String = "D" {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(hotkeyKeyChar, forKey: "hotkeyKeyChar") }
    }

    /// Human-readable shortcut string (e.g. "⌃⌥⇧⌘D").
    var hotkeyDisplayString: String {
        guard hotkeyEnabled else { return "None" }
        var parts: [String] = []
        let mods = NSEvent.ModifierFlags(rawValue: hotkeyModifiers)
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(hotkeyKeyChar)
        return parts.joined()
    }

    // MARK: - Alerts

    var playSoundOnNudge: Bool = true {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(playSoundOnNudge, forKey: "playSoundOnNudge") }
    }

    var autoOpenOnNudge: Bool = true {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(autoOpenOnNudge, forKey: "autoOpenOnNudge") }
    }

    var autoOpenDelaySeconds: Int = 60 {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(autoOpenDelaySeconds, forKey: "autoOpenDelaySeconds") }
    }

    var snoozeDurationMinutes: Int = 30 {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(snoozeDurationMinutes, forKey: "snoozeDurationMinutes") }
    }

    // MARK: - Display

    var showElapsedInMenuBar: Bool = false {
        didSet { guard !isLoading else { return }; UserDefaults.standard.set(showElapsedInMenuBar, forKey: "showElapsedInMenuBar") }
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "hotkeyEnabled") != nil { hotkeyEnabled = d.bool(forKey: "hotkeyEnabled") }
        if d.object(forKey: "hotkeyModifiers") != nil { hotkeyModifiers = UInt(d.integer(forKey: "hotkeyModifiers")) }
        if d.object(forKey: "hotkeyKeyCode") != nil { hotkeyKeyCode = d.integer(forKey: "hotkeyKeyCode") }
        if let char = d.string(forKey: "hotkeyKeyChar"), !char.isEmpty { hotkeyKeyChar = char }
        if d.object(forKey: "playSoundOnNudge") != nil { playSoundOnNudge = d.bool(forKey: "playSoundOnNudge") }
        if d.object(forKey: "autoOpenOnNudge") != nil { autoOpenOnNudge = d.bool(forKey: "autoOpenOnNudge") }
        if d.object(forKey: "autoOpenDelaySeconds") != nil { autoOpenDelaySeconds = d.integer(forKey: "autoOpenDelaySeconds") }
        if d.object(forKey: "snoozeDurationMinutes") != nil { snoozeDurationMinutes = d.integer(forKey: "snoozeDurationMinutes") }
        if d.object(forKey: "showElapsedInMenuBar") != nil { showElapsedInMenuBar = d.bool(forKey: "showElapsedInMenuBar") }
        isLoading = false
    }
}
