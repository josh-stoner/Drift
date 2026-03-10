// SessionDetailView.swift
// Expanded view of a single WorkSession — shows a timeline of start, nudge events,
// responses, and end.

import SwiftUI

struct SessionDetailView: View {
    let session: WorkSession
    let patterns: [Pattern]
    let onBack: () -> Void

    var body: some View {
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
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            // Task name
            Text(session.taskName)
                .font(CMFont.heading)
                .foregroundStyle(Color.cmTextPrimary)
                .padding(.horizontal, CMSpacing.md)
                .padding(.bottom, CMSpacing.sm)

            Divider()
                .opacity(0.2)

            // MARK: Summary strip
            HStack(spacing: CMSpacing.lg) {
                statPill(label: "Duration", value: session.durationString)
                statPill(label: "Estimate", value: TimeInterval.formatElapsed(session.estimateInterval))
                statPill(label: "Nudges", value: "\(session.nudges.count)")
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)

            Divider()
                .opacity(0.2)

            // MARK: Timeline
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    timelineEvent(
                        icon: "play.fill",
                        color: Color.cmGreen,
                        label: "Started",
                        time: session.startedAt
                    )

                    ForEach(session.nudges) { nudge in
                        nudgeTimelineRow(nudge: nudge)
                    }

                    if let end = session.endedAt {
                        timelineEvent(
                            icon: "stop.fill",
                            color: Color.cmTextTertiary,
                            label: "Ended",
                            time: end
                        )
                    }
                }
                .padding(.vertical, CMSpacing.sm)
            }
            .frame(maxHeight: 280)
        }
    }

    // MARK: - Timeline helpers

    @ViewBuilder
    private func timelineEvent(icon: String, color: Color, label: String, time: Date) -> some View {
        HStack(alignment: .top, spacing: CMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(CMFont.itemSubtitle)
                .foregroundStyle(Color.cmTextSecondary)
            Spacer()
            Text(timeLabel(time))
                .font(CMFont.mono)
                .foregroundStyle(Color.cmTextTertiary)
        }
        .padding(.horizontal, CMSpacing.md)
        .padding(.vertical, CMSpacing.xs)
    }

    @ViewBuilder
    private func nudgeTimelineRow(nudge: NudgeRecord) -> some View {
        let patternName = patterns.first(where: { $0.id == nudge.patternId })?.name ?? "Pattern"
        let responseColor = responseColor(for: nudge.response)
        let responseLabel = responseLabel(for: nudge.response)

        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: CMSpacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cmMauve)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(patternName)
                        .font(CMFont.itemSubtitle)
                        .foregroundStyle(Color.cmMauve)
                    Text(nudge.renderedMessage)
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmTextTertiary)
                        .lineLimit(2)
                }
                Spacer()
                Text(timeLabel(nudge.firedAt))
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            }

            if nudge.response != nil {
                HStack(spacing: CMSpacing.sm) {
                    Spacer().frame(width: 16 + CMSpacing.sm)
                    Text(responseLabel)
                        .font(CMFont.mono)
                        .foregroundStyle(responseColor)
                    if let respondedAt = nudge.respondedAt {
                        Text("at \(timeLabel(respondedAt))")
                            .font(CMFont.mono)
                            .foregroundStyle(Color.cmTextTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, CMSpacing.md)
        .padding(.vertical, CMSpacing.xs)
    }

    @ViewBuilder
    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CMFont.mono)
                .foregroundStyle(Color.cmTextTertiary)
            Text(value)
                .font(CMFont.monoBody)
                .foregroundStyle(Color.cmTextPrimary)
        }
    }

    // MARK: - Formatting

    private func timeLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func responseLabel(for response: NudgeResponse?) -> String {
        switch response {
        case .acknowledged: return "Acknowledged"
        case .dismissed:    return "Dismissed"
        case .snoozed:      return "Snoozed"
        case nil:           return "No response"
        }
    }

    private func responseColor(for response: NudgeResponse?) -> Color {
        switch response {
        case .acknowledged: return Color.cmGreen
        case .dismissed:    return Color.cmTextSecondary
        case .snoozed:      return Color.cmWarning
        case nil:           return Color.cmTextTertiary
        }
    }
}

#Preview {
    let store = DriftStore()
    let session = WorkSession(
        taskName: "Auth scaffold setup",
        estimateMinutes: 60,
        startedAt: Date().addingTimeInterval(-7200),
        endedAt: Date().addingTimeInterval(-3600),
        nudges: [
            NudgeRecord(
                patternId: store.patterns[0].id,
                firedAt: Date().addingTimeInterval(-5400),
                response: .acknowledged,
                respondedAt: Date().addingTimeInterval(-5200),
                renderedMessage: "You're at 30m on a task you scoped for 1h.",
                fireIndex: 1
            )
        ]
    )
    return SessionDetailView(
        session: session,
        patterns: store.patterns,
        onBack: {}
    )
    .frame(width: 360)
    .background(Color.cmBackground)
    .preferredColorScheme(.dark)
}
