// StartSessionView.swift
// Inline form within the popover for creating a new work session.
// Task name field auto-focuses; estimate uses a stepper in 15-min increments.

import SwiftUI

struct StartSessionView: View {
    let store: DriftStore
    let engine: PatternEngine
    let onStarted: () -> Void
    let onCancel: () -> Void

    @State private var taskName: String = ""
    @State private var estimateMinutes: Int = 60
    @State private var showSuggestions = false
    @FocusState private var isTaskFieldFocused: Bool

    private let minEstimate = 15
    private let maxEstimate = 480  // 8 hours
    private let step = 15

    /// Unique recent task names for quick-start suggestions.
    private var recentTasks: [String] {
        Array(
            store.sessions
                .map(\.taskName)
                .reduce(into: [String]()) { result, name in
                    if !result.contains(name) { result.append(name) }
                }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header
            HStack {
                Text("NEW SESSION")
                    .font(CMFont.sectionHeader)
                    .tracking(CMTracking.header)
                    .foregroundStyle(Color.cmTextTertiary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cmTextTertiary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.top, CMSpacing.md)
            .padding(.bottom, CMSpacing.sm)

            Divider()
                .opacity(0.2)

            VStack(alignment: .leading, spacing: CMSpacing.lg) {
                // MARK: Task name
                VStack(alignment: .leading, spacing: CMSpacing.xs) {
                    Text("WHAT ARE YOU WORKING ON?")
                        .font(CMFont.sectionHeader)
                        .tracking(CMTracking.header)
                        .foregroundStyle(Color.cmTextTertiary)

                    TextField("Task name\u{2026}", text: $taskName)
                        .textFieldStyle(.plain)
                        .font(CMFont.body)
                        .foregroundStyle(Color.cmTextPrimary)
                        .padding(.horizontal, CMSpacing.sm)
                        .padding(.vertical, CMSpacing.sm)
                        .background(Color.cmSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .focused($isTaskFieldFocused)
                        .onSubmit { if canStart { beginSession() } }

                    // Recent task suggestions
                    if !recentTasks.isEmpty && taskName.isEmpty {
                        HStack(spacing: CMSpacing.xs) {
                            ForEach(recentTasks.prefix(3), id: \.self) { name in
                                Button(action: { taskName = name }) {
                                    Text(name)
                                        .font(CMFont.mono)
                                        .foregroundStyle(Color.cmTextSecondary)
                                        .lineLimit(1)
                                        .padding(.horizontal, CMSpacing.sm)
                                        .padding(.vertical, 3)
                                        .background(Color.cmSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // MARK: Estimate stepper
                VStack(alignment: .leading, spacing: CMSpacing.xs) {
                    Text("ESTIMATE")
                        .font(CMFont.sectionHeader)
                        .tracking(CMTracking.header)
                        .foregroundStyle(Color.cmTextTertiary)

                    HStack(spacing: CMSpacing.sm) {
                        Button(action: decrementEstimate) {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 32, height: 32)
                                .background(Color.cmSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(estimateMinutes <= minEstimate ? Color.cmTextTertiary : Color.cmTextSecondary)
                        .disabled(estimateMinutes <= minEstimate)

                        Text(estimateLabel)
                            .font(CMFont.monoBody)
                            .foregroundStyle(Color.cmTextPrimary)
                            .frame(minWidth: 70, alignment: .center)
                            .padding(.horizontal, CMSpacing.sm)
                            .padding(.vertical, CMSpacing.sm)
                            .background(Color.cmSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button(action: incrementEstimate) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 32, height: 32)
                                .background(Color.cmSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(estimateMinutes >= maxEstimate ? Color.cmTextTertiary : Color.cmTextSecondary)
                        .disabled(estimateMinutes >= maxEstimate)
                    }
                }
            }
            .padding(CMSpacing.md)

            Divider()
                .opacity(0.2)

            // MARK: Actions
            HStack(spacing: CMSpacing.sm) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(CMFont.body)
                    .foregroundStyle(Color.cmTextSecondary)
                    .padding(.vertical, CMSpacing.sm)

                Spacer()

                Button("Start") { beginSession() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!canStart)
            }
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, CMSpacing.sm)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isTaskFieldFocused = true
            }
        }
    }

    // MARK: - Helpers

    private var canStart: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var estimateLabel: String {
        let hours = estimateMinutes / 60
        let minutes = estimateMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func incrementEstimate() {
        estimateMinutes = min(estimateMinutes + step, maxEstimate)
    }

    private func decrementEstimate() {
        estimateMinutes = max(estimateMinutes - step, minEstimate)
    }

    private func beginSession() {
        let name = taskName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.startSession(taskName: name, estimateMinutes: estimateMinutes)
        engine.sessionDidStart()
        onStarted()
    }
}

#Preview {
    StartSessionView(
        store: DriftStore(),
        engine: PatternEngine(store: DriftStore()),
        onStarted: {},
        onCancel: {}
    )
    .frame(width: 360)
    .background(Color.cmBackground)
    .preferredColorScheme(.dark)
}
