// PatternRow.swift
// Reusable row showing a pattern's status dot, name, and current threshold info.
// Used in ActiveSessionView for the live pattern list.

import SwiftUI

struct PatternRow: View {
    let pattern: Pattern
    let statusDescription: String
    let hasFired: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: CMSpacing.sm) {
            // Status dot
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            // Pattern name + threshold info
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.name)
                    .font(CMFont.itemTitle)
                    .foregroundStyle(hasFired ? Color.cmTextSecondary : Color.cmTextPrimary)
                    .lineLimit(1)
                Text(statusDescription)
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, CMSpacing.md)
        .padding(.vertical, CMSpacing.sm)
        .background(isHovering ? Color.cmHover : Color.clear)
        .onHover { isHovering = $0 }
    }

    private var dotColor: Color {
        if hasFired { return Color.cmTextTertiary }
        switch pattern.triggerType {
        case .scopeCreep:         return Color.cmWarning
        case .infrastructureFirst: return Color.cmAccent
        case .boredom:            return Color.cmMauve
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        PatternRow(
            pattern: DriftStore.defaultPatterns[0],
            statusDescription: "Fires at 2h · you're at 45m",
            hasFired: false
        )
        PatternRow(
            pattern: DriftStore.defaultPatterns[1],
            statusDescription: "Done this session",
            hasFired: true
        )
        PatternRow(
            pattern: DriftStore.defaultPatterns[2],
            statusDescription: "Fires at 3h · you're at 1h 12m",
            hasFired: false
        )
    }
    .frame(width: 360)
    .background(Color.cmBackground)
    .preferredColorScheme(.dark)
}
