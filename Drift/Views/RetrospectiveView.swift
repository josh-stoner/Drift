// RetrospectiveView.swift
// Scrollable list of past sessions. Tapping a row expands to SessionDetailView.

import SwiftUI

struct RetrospectiveView: View {
    let store: DriftStore
    let onBack: () -> Void

    @State private var selectedSession: WorkSession? = nil

    var body: some View {
        if let session = selectedSession {
            SessionDetailView(
                session: session,
                patterns: store.patterns,
                onBack: { withAnimation(.cmDefault) { selectedSession = nil } }
            )
        } else {
            sessionList
        }
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: CMSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Back")
                            .font(CMFont.body)
                    }
                    .foregroundStyle(Color.cmAccent)
                    .padding(.vertical, CMSpacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(store.sessions.count)")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider()
                .opacity(0.2)

            if store.sessions.isEmpty {
                VStack(spacing: CMSpacing.sm) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.cmTextTertiary)
                    Text("No sessions yet")
                        .font(CMFont.body)
                        .foregroundStyle(Color.cmTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CMSpacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.sessions) { session in
                            SessionRow(session: session, patterns: store.patterns) {
                                withAnimation(.cmDefault) { selectedSession = session }
                            }
                            if session.id != store.sessions.last?.id {
                                Divider()
                                    .padding(.leading, CMSpacing.md)
                                    .opacity(0.1)
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
    }
}

// MARK: - Session list row

private struct SessionRow: View {
    let session: WorkSession
    let patterns: [Pattern]
    let onTap: () -> Void

    @State private var isHovering = false

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .none
        return fmt.string(from: session.startedAt)
    }

    private var overrunLabel: String? {
        guard session.progressRatio > 1.0 else { return nil }
        let pct = Int((session.progressRatio - 1.0) * 100)
        return "+\(pct)%"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CMSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.taskName)
                        .font(CMFont.itemTitle)
                        .foregroundStyle(Color.cmTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: CMSpacing.xs) {
                        Text(dateLabel)
                            .font(CMFont.mono)
                            .foregroundStyle(Color.cmTextTertiary)
                        Text("\u{00B7}")
                            .font(CMFont.mono)
                            .foregroundStyle(Color.cmTextTertiary)
                        Text(session.durationString)
                            .font(CMFont.mono)
                            .foregroundStyle(Color.cmTextTertiary)
                        if let overrun = overrunLabel {
                            Text(overrun)
                                .font(CMFont.mono)
                                .foregroundStyle(Color.cmWarning)
                        }
                    }
                }
                Spacer()
                if !session.nudges.isEmpty {
                    Text("\(session.nudges.count)N")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmMauve)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cmTextTertiary)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.cmHover : Color.clear)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    let store = DriftStore()
    return RetrospectiveView(store: store, onBack: {})
        .frame(width: 360)
        .background(Color.cmBackground)
        .preferredColorScheme(.dark)
}
