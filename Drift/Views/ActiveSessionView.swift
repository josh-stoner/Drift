// ActiveSessionView.swift
// Shown while a session is running. Timer ticks every second.

import SwiftUI

struct ActiveSessionView: View {
    let store: DriftStore
    let engine: PatternEngine
    let onEndSession: () -> Void
    let onShowRetro: () -> Void

    @State private var displayTick: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let _ = displayTick
            if let session = store.activeSession {
                activeContent(session: session)
            } else {
                // Defensive fallback if session ends mid-display
                IdleView(store: store, onStartSession: {}, onShowRetro: {})
            }
        }
    }

    @ViewBuilder
    private func activeContent(session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("ACTIVE")
                    .font(CMFont.sectionHeader)
                    .tracking(CMTracking.header)
                    .foregroundStyle(Color.cmAccent)
                Spacer()
                Button(action: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(name: .driftOpenMainWindow, object: nil)
                    }
                }) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cmTextTertiary)
                }
                .buttonStyle(.plain)
                .help("Open Drift window")

                Button(action: onShowRetro) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cmTextTertiary)
                }
                .buttonStyle(.plain)
                .help("Past sessions")
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider().opacity(0.2)

            // Session info
            VStack(alignment: .leading, spacing: CMSpacing.sm) {
                Text(session.taskName)
                    .font(CMFont.itemTitle)
                    .foregroundStyle(Color.cmTextPrimary)
                    .lineLimit(1)

                Text(TimeInterval.formatElapsed(session.elapsed))
                    .font(CMFont.timerLarge)
                    .foregroundStyle(elapsedColor(ratio: session.progressRatio))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Text("est. \(TimeInterval.formatElapsed(session.estimateInterval))")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmTextTertiary)
                    Spacer()
                    Text(ratioLabel(session.progressRatio))
                        .font(CMFont.mono)
                        .foregroundStyle(elapsedColor(ratio: session.progressRatio))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.cmSurfaceRaised)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(progressBarColor(ratio: session.progressRatio))
                            .frame(width: min(geo.size.width * CGFloat(session.progressRatio), geo.size.width), height: 3)
                            .animation(.cmDefault, value: session.progressRatio)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)

            Divider().opacity(0.2)

            // Pattern rows
            ForEach(store.patterns) { pattern in
                PatternRow(
                    pattern: pattern,
                    statusDescription: engine.statusDescription(for: pattern, session: session),
                    hasFired: engine.hasFired(patternId: pattern.id)
                )
            }

            Divider().opacity(0.2)

            // End session
            Button(action: onEndSession) {
                Text("End Session")
                    .font(CMFont.body)
                    .foregroundStyle(Color.cmError.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CMSpacing.sm)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CMSpacing.md)
            .contentShape(Rectangle())
            .help("End the current session")
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            displayTick += 1
        }
    }

    private func elapsedColor(ratio: Double) -> Color {
        if ratio >= 1.5 { return Color.cmError }
        if ratio >= 1.0 { return Color.cmWarning }
        return Color.cmTextPrimary
    }

    private func progressBarColor(ratio: Double) -> Color {
        if ratio >= 1.5 { return Color.cmError }
        if ratio >= 1.0 { return Color.cmWarning }
        return Color.cmGreen
    }

    private func ratioLabel(_ ratio: Double) -> String {
        if ratio > 1.0 { return "+\(Int((ratio - 1.0) * 100))% over" }
        return "\(Int(ratio * 100))%"
    }
}
