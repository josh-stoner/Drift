// SessionSummaryView.swift
// Shown briefly after ending a session — quick recap of duration, nudges, and overrun.

import SwiftUI

struct SessionSummaryView: View {
    let session: WorkSession
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SESSION COMPLETE")
                    .font(CMFont.sectionHeader)
                    .tracking(CMTracking.header)
                    .foregroundStyle(Color.cmGreen)
                Spacer()
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider().opacity(0.2)

            VStack(alignment: .leading, spacing: CMSpacing.md) {
                Text(session.taskName)
                    .font(CMFont.itemTitle)
                    .foregroundStyle(Color.cmTextPrimary)
                    .lineLimit(2)

                // Stats grid
                HStack(spacing: CMSpacing.lg) {
                    statBlock("Duration", session.durationString)
                    statBlock("Estimate", TimeInterval.formatElapsed(session.estimateInterval))
                    statBlock("Nudges", "\(session.nudges.count)")
                }

                // Overrun indicator
                if session.progressRatio > 1.0 {
                    HStack(spacing: CMSpacing.sm) {
                        Circle()
                            .fill(session.progressRatio >= 1.5 ? Color.cmError : Color.cmWarning)
                            .frame(width: 7, height: 7)
                        Text("+\(Int((session.progressRatio - 1.0) * 100))% over estimate")
                            .font(CMFont.mono)
                            .foregroundStyle(session.progressRatio >= 1.5 ? Color.cmError : Color.cmWarning)
                    }
                } else {
                    HStack(spacing: CMSpacing.sm) {
                        Circle()
                            .fill(Color.cmGreen)
                            .frame(width: 7, height: 7)
                        Text("Completed within estimate")
                            .font(CMFont.mono)
                            .foregroundStyle(Color.cmGreen)
                    }
                }

                // Nudge breakdown
                if !session.nudges.isEmpty {
                    let heeded = session.nudges.filter { $0.response == .acknowledged }.count
                    let dismissed = session.nudges.filter { $0.response == .dismissed }.count
                    let snoozed = session.nudges.filter { $0.response == .snoozed }.count
                    HStack(spacing: CMSpacing.sm) {
                        if heeded > 0 {
                            Text("\(heeded) heeded")
                                .font(CMFont.mono)
                                .foregroundStyle(Color.cmGreen)
                        }
                        if dismissed > 0 {
                            Text("\(dismissed) dismissed")
                                .font(CMFont.mono)
                                .foregroundStyle(Color.cmTextTertiary)
                        }
                        if snoozed > 0 {
                            Text("\(snoozed) snoozed")
                                .font(CMFont.mono)
                                .foregroundStyle(Color.cmWarning)
                        }
                    }
                }
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)

            Divider().opacity(0.2)

            Button(action: onDismiss) {
                Text("Done")
                    .font(CMFont.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CMSpacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.sm)
        }
    }

    @ViewBuilder
    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CMFont.mono)
                .foregroundStyle(Color.cmTextTertiary)
            Text(value)
                .font(CMFont.monoBody)
                .foregroundStyle(Color.cmTextPrimary)
        }
    }
}
