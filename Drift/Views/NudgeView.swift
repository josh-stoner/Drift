// NudgeView.swift
// Nudge card shown when a pattern fires. Elevated background, Mauve pattern name,
// message text, and three response buttons with A/D/S keyboard shortcuts.

import SwiftUI
import AppKit

struct NudgeView: View {
    let engine: PatternEngine
    let onResponded: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        if let pending = engine.pendingNudge {
            nudgeContent(pending: pending)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func nudgeContent(pending: (pattern: Pattern, nudge: NudgeRecord)) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header
            HStack {
                Text("PATTERN INTERRUPT")
                    .font(CMFont.sectionHeader)
                    .tracking(CMTracking.header)
                    .foregroundStyle(Color.cmMauve)
                Spacer()
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider()
                .opacity(0.3)

            // MARK: Nudge card
            VStack(alignment: .leading, spacing: CMSpacing.sm) {
                Text(pending.pattern.name)
                    .font(CMFont.itemTitle)
                    .foregroundStyle(Color.cmMauve)

                Text(pending.nudge.renderedMessage)
                    .font(CMFont.body)
                    .foregroundStyle(Color.cmTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)

            Divider()
                .opacity(0.2)

            // MARK: Response buttons
            VStack(spacing: 0) {
                NudgeResponseButton(
                    label: "Acknowledge",
                    shortcut: "A",
                    color: Color.cmGreen
                ) {
                    respond(.acknowledged)
                }

                Divider()
                    .padding(.leading, CMSpacing.md)
                    .opacity(0.1)

                NudgeResponseButton(
                    label: "Dismiss",
                    shortcut: "D",
                    color: Color.cmTextSecondary
                ) {
                    respond(.dismissed)
                }

                Divider()
                    .padding(.leading, CMSpacing.md)
                    .opacity(0.1)

                NudgeResponseButton(
                    label: "Snooze \(engine.settings.snoozeDurationMinutes)m",
                    shortcut: "S",
                    color: Color.cmWarning
                ) {
                    respond(.snoozed)
                }
            }

            if pending.nudge.fireIndex > 1 {
                HStack {
                    Spacer()
                    Text("Reminder \(pending.nudge.fireIndex) \u{00B7} final notice")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmWarning.opacity(0.7))
                }
                .padding(.horizontal, CMSpacing.md)
                .padding(.vertical, CMSpacing.xs)
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress("a") { respond(.acknowledged); return .handled }
        .onKeyPress("d") { respond(.dismissed); return .handled }
        .onKeyPress("s") { respond(.snoozed); return .handled }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pattern interrupt: \(pending.pattern.name)")
    }

    private func respond(_ response: NudgeResponse) {
        withAnimation(.easeIn(duration: 0.15)) {
            engine.respondToPendingNudge(response: response)
        }
        // Small delay so the animation plays before route changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onResponded()
        }
    }
}

// MARK: - Response button component

private struct NudgeResponseButton: View {
    let label: String
    let shortcut: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CMSpacing.sm) {
                Text(label)
                    .font(CMFont.body)
                    .foregroundStyle(color)
                Spacer()
                Text(shortcut)
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
                    .padding(.horizontal, CMSpacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.cmSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.sm + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.cmHover : Color.clear)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    let store = DriftStore()
    store.startSession(taskName: "Auth scaffold setup", estimateMinutes: 60)
    let engine = PatternEngine(store: store)
    let nudge = NudgeRecord(
        patternId: store.patterns[0].id,
        renderedMessage: "You're at 2h 10m on a task you scoped for 1h. Last time this happened, you hit 15.5 hours on a 1-day task. What's the smallest version you can ship right now?",
        fireIndex: 1
    )
    engine.pendingNudge = (pattern: store.patterns[0], nudge: nudge)
    return NudgeView(engine: engine, onResponded: {})
        .frame(width: 360)
        .background(Color.cmSurfaceRaised)
        .preferredColorScheme(.dark)
}
