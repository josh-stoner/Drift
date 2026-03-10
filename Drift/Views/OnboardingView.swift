// OnboardingView.swift
// First-launch welcome shown in the popover. Explains Drift in 3 bullets and starts first session.

import SwiftUI

struct OnboardingView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("WELCOME TO DRIFT")
                    .font(CMFont.sectionHeader)
                    .tracking(CMTracking.header)
                    .foregroundStyle(Color.cmAccent)
                Spacer()
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider().opacity(0.2)

            VStack(alignment: .leading, spacing: CMSpacing.md) {
                featureRow(
                    icon: "timer",
                    color: Color.cmAccent,
                    title: "Name a task + estimate",
                    subtitle: "Start a focused work session with a time scope"
                )
                featureRow(
                    icon: "waveform.path",
                    color: Color.cmMauve,
                    title: "Pattern awareness",
                    subtitle: "Drift watches for scope creep, gold-plating, and drift"
                )
                featureRow(
                    icon: "hand.raised",
                    color: Color.cmWarning,
                    title: "Gentle nudges",
                    subtitle: "Get interrupted before a 1-hour task becomes a 15-hour rabbit hole"
                )
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.md)

            Divider().opacity(0.2)

            Button(action: onDismiss) {
                Text("Get Started")
                    .font(CMFont.itemTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CMSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.sm)
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: CMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CMFont.itemTitle)
                    .foregroundStyle(Color.cmTextPrimary)
                Text(subtitle)
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
