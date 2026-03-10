// IdleView.swift
// Shown when no session is active.

import SwiftUI

struct IdleView: View {
    let store: DriftStore
    let onStartSession: () -> Void
    let onShowRetro: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DRIFT")
                    .font(CMFont.sectionHeader)
                    .tracking(CMTracking.header)
                    .foregroundStyle(Color.cmTextTertiary)
                Spacer()
                Button(action: openWindow) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cmTextTertiary)
                }
                .buttonStyle(.plain)
                .help("Open Drift window")
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider().opacity(0.2)

            // Start button
            VStack(spacing: CMSpacing.sm) {
                Button(action: onStartSession) {
                    Text("Start Session")
                        .font(CMFont.itemTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CMSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Name a task + estimate \u{2192} Drift watches for patterns")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)

            Divider().opacity(0.2)

            // Pattern status dots
            ForEach(store.patterns) { pattern in
                PatternStatusRow(pattern: pattern)
            }

            // Last session
            if let last = store.sessions.first {
                Divider().opacity(0.2)
                Button(action: onShowRetro) {
                    HStack(spacing: CMSpacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last: \(last.taskName)")
                                .font(CMFont.itemSubtitle)
                                .foregroundStyle(Color.cmTextSecondary)
                                .lineLimit(1)
                            Text("\(last.durationString) \u{00B7} \(last.nudgeSummary)")
                                .font(CMFont.mono)
                                .foregroundStyle(Color.cmTextTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.cmTextTertiary)
                    }
                    .padding(.horizontal, CMSpacing.md)
                    .padding(.vertical, CMSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .driftOpenMainWindow, object: nil)
        }
    }
}

// MARK: - Pattern status row

private struct PatternStatusRow: View {
    let pattern: Pattern
    @State private var isHovering = false

    private var dotColor: Color {
        guard pattern.isEnabled else { return Color.cmTextTertiary }
        switch pattern.triggerType {
        case .scopeCreep:        return Color.cmWarning
        case .infrastructureFirst: return Color.cmAccent
        case .boredom:           return Color.cmMauve
        }
    }

    var body: some View {
        HStack(spacing: CMSpacing.sm) {
            Circle().fill(dotColor).frame(width: 7, height: 7)
            Text(pattern.name)
                .font(CMFont.itemSubtitle)
                .foregroundStyle(pattern.isEnabled ? Color.cmTextSecondary : Color.cmTextTertiary)
            Spacer()
            if !pattern.isEnabled {
                Text("off")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            } else {
                Text(pattern.fireCount == 0 ? "ready" : "\(pattern.fireCount) fires")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            }
        }
        .padding(.horizontal, CMSpacing.md)
        .padding(.vertical, CMSpacing.sm)
        .background(isHovering ? Color.cmHover : Color.clear)
        .onHover { isHovering = $0 }
    }
}
