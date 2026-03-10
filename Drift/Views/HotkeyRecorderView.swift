// HotkeyRecorderView.swift
// Click-to-record keyboard shortcut field.
// Captures modifier flags + key code on the next keyDown after entering recording mode.

import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @Bindable var settings: DriftSettings

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: { startRecording() }) {
            Text(isRecording ? "Press shortcut\u{2026}" : settings.hotkeyDisplayString)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(isRecording ? Color.cmTextTertiary : Color.cmTextPrimary)
                .padding(.horizontal, CMSpacing.sm + 2)
                .padding(.vertical, 5)
                .background(Color.cmSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRecording ? Color.cmAccent : Color.cmBorder.opacity(0.4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Escape → cancel without changing
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            // Delete/Backspace → clear shortcut (disable)
            if event.keyCode == 51 {
                settings.hotkeyEnabled = false
                stopRecording()
                return nil
            }

            // Require at least one real modifier (not just Fn/CapsLock)
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting([.function, .capsLock, .numericPad])
            guard !mods.isEmpty else { return nil }

            // Capture the combo
            settings.hotkeyModifiers = mods.rawValue
            settings.hotkeyKeyCode = Int(event.keyCode)
            settings.hotkeyKeyChar = displayName(for: event)
            settings.hotkeyEnabled = true
            stopRecording()

            return nil // consume event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Key name

    private func displayName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 76: return "Enter"
        case 123: return "\u{2190}"
        case 124: return "\u{2192}"
        case 125: return "\u{2193}"
        case 126: return "\u{2191}"
        case 122: return "F1"
        case 120: return "F2"
        case 99:  return "F3"
        case 118: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "?"
        }
    }
}
