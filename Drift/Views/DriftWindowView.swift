// DriftWindowView.swift
// Unified app window — sidebar navigation with Session, History, and Settings panels.
// Fixed-size window with opaque Catppuccin Mocha surfaces.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar tabs

enum WindowTab: String, CaseIterable {
    case session  = "Session"
    case history  = "History"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .session:  return "timer"
        case .history:  return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Root

struct DriftWindowView: View {
    @Bindable var store: DriftStore
    @Bindable var engine: PatternEngine
    @Bindable var settings: DriftSettings

    @State private var selectedTab: WindowTab = .session
    @State private var displayTick: Int = 0

    private let titlebarHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.3)
            content
        }
        .frame(width: 560, height: 580)
        .background(Color.cmBackground)
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            displayTick += 1
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: CMSpacing.xs) {
            ForEach(WindowTab.allCases, id: \.self) { tab in
                SidebarButton(tab: tab, isSelected: selectedTab == tab) {
                    withAnimation(.cmDefault) { selectedTab = tab }
                }
            }
            Spacer()
        }
        .padding(.top, titlebarHeight + CMSpacing.sm)
        .padding(.horizontal, CMSpacing.sm)
        .padding(.bottom, CMSpacing.lg)
        .frame(width: 64)
        .background(Color.cmBase)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .session:
            SessionPanel(store: store, engine: engine, displayTick: displayTick, titlebarHeight: titlebarHeight)
        case .history:
            HistoryPanel(store: store, titlebarHeight: titlebarHeight)
        case .settings:
            SettingsPanel(store: store, settings: settings, titlebarHeight: titlebarHeight)
        }
    }
}

// MARK: - Sidebar Button (with hover state — CV-1 fix)

private struct SidebarButton: View {
    let tab: WindowTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.cmAccent : Color.cmTextTertiary)
            .frame(width: 48, height: 48)
            .background(isSelected ? Color.cmSelected : (isHovering ? Color.cmHover : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(tab.rawValue) tab")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Session Panel

private struct SessionPanel: View {
    @Bindable var store: DriftStore
    let engine: PatternEngine
    let displayTick: Int
    let titlebarHeight: CGFloat

    var body: some View {
        ScrollView {
            let _ = displayTick
            VStack(alignment: .leading, spacing: CMSpacing.lg) {
                if let session = store.activeSession {
                    activeView(session)
                } else {
                    idleView
                }

                // Patterns
                VStack(alignment: .leading, spacing: CMSpacing.sm) {
                    Text("PATTERNS")
                        .font(CMFont.sectionHeader)
                        .foregroundStyle(Color.cmTextTertiary)
                        .tracking(CMTracking.header)

                    GlassCard {
                        ForEach(store.patterns) { pattern in
                            if pattern != store.patterns.first {
                                Divider().opacity(0.15)
                            }
                            HStack(spacing: CMSpacing.sm) {
                                Circle()
                                    .fill(pattern.isEnabled ? dotColor(for: pattern) : Color.cmTextTertiary)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pattern.name)
                                        .font(CMFont.itemTitle)
                                        .foregroundStyle(pattern.isEnabled ? Color.cmTextPrimary : Color.cmTextTertiary)
                                    if let session = store.activeSession, pattern.isEnabled {
                                        Text(engine.statusDescription(for: pattern, session: session))
                                            .font(CMFont.mono)
                                            .foregroundStyle(Color.cmTextTertiary)
                                    }
                                }
                                Spacer()
                                if !pattern.isEnabled {
                                    Text("OFF")
                                        .font(CMFont.mono)
                                        .foregroundStyle(Color.cmTextTertiary)
                                }
                            }
                            .padding(.vertical, CMSpacing.xs)
                        }
                    }
                }
            }
            .padding(.top, titlebarHeight + CMSpacing.md)
            .padding(.horizontal, CMSpacing.lg)
            .padding(.bottom, CMSpacing.lg)
        }
    }

    @ViewBuilder
    private func activeView(_ session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: CMSpacing.lg) {
            Text(session.taskName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.cmTextPrimary)

            GlassCard {
                VStack(spacing: CMSpacing.sm) {
                    Text(TimeInterval.formatElapsed(session.elapsed))
                        .font(CMFont.timerLarge)
                        .foregroundStyle(elapsedColor(ratio: session.progressRatio))
                        .frame(maxWidth: .infinity)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cmSurfaceRaised)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progressBarColor(ratio: session.progressRatio))
                                .frame(width: min(geo.size.width * CGFloat(session.progressRatio), geo.size.width), height: 4)
                                .animation(.cmDefault, value: session.progressRatio)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("est. \(TimeInterval.formatElapsed(session.estimateInterval))")
                            .font(CMFont.mono)
                            .foregroundStyle(Color.cmTextTertiary)
                        Spacer()
                        Text(ratioLabel(session.progressRatio))
                            .font(CMFont.mono)
                            .foregroundStyle(elapsedColor(ratio: session.progressRatio))
                    }
                }
            }

            Button(action: {
                engine.sessionDidEnd()
                store.endSession()
            }) {
                HStack(spacing: CMSpacing.sm) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                    Text("End Session")
                        .font(CMFont.body)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CMSpacing.sm)
            }
            .buttonStyle(.bordered)
            .tint(Color.cmError)
            .keyboardShortcut("e", modifiers: .command)
            .help("End session (\u{2318}E)")
        }
    }

    private var idleView: some View {
        GlassCard {
            VStack(spacing: CMSpacing.md) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(Color.cmTextTertiary)
                Text("No active session")
                    .font(CMFont.body)
                    .foregroundStyle(Color.cmTextSecondary)
                Text("Click the menu bar icon to start")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CMSpacing.lg)
        }
    }

    private func dotColor(for pattern: Pattern) -> Color {
        switch pattern.triggerType {
        case .scopeCreep:        return Color.cmWarning
        case .infrastructureFirst: return Color.cmAccent
        case .boredom:           return Color.cmMauve
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

// MARK: - History Panel

private struct HistoryPanel: View {
    @Bindable var store: DriftStore
    let titlebarHeight: CGFloat

    @State private var editingSession: WorkSession?
    @State private var selectedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Session History")
                    .font(CMFont.heading)
                    .foregroundStyle(Color.cmTextPrimary)
                Spacer()
                Text("\(store.sessions.count) sessions")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            }
            .padding(.top, titlebarHeight + CMSpacing.md)
            .padding(.horizontal, CMSpacing.lg)
            .padding(.bottom, CMSpacing.md)

            if store.sessions.isEmpty {
                // Compact top-aligned empty state (CV-5 fix)
                VStack(spacing: CMSpacing.sm) {
                    Image(systemName: "clock")
                        .font(.system(size: 24, weight: .thin))
                        .foregroundStyle(Color.cmTextTertiary)
                    Text("No sessions yet")
                        .font(CMFont.body)
                        .foregroundStyle(Color.cmTextTertiary)
                    Text("Start a session from the menu bar")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CMSpacing.lg)
                Spacer()
            } else {
                List(selection: $selectedId) {
                    ForEach(store.sessions) { session in
                        HistoryRow(session: session)
                            .tag(session.id)
                            .listRowBackground(
                                selectedId == session.id
                                ? Color.cmSurface
                                : Color.clear
                            )
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button("Edit\u{2026}") { editingSession = session }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    withAnimation { store.deleteSession(id: session.id) }
                                }
                            }
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { store.sessions[$0].id }
                        withAnimation { store.deleteSessions(ids: Set(ids)) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditSheet(store: store, session: session) { editingSession = nil }
        }
    }
}

private struct HistoryRow: View {
    let session: WorkSession

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: session.startedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.taskName)
                .font(CMFont.itemTitle)
                .foregroundStyle(Color.cmTextPrimary)
                .lineLimit(1)
            HStack(spacing: CMSpacing.sm) {
                Text(dateLabel)
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
                Text(session.durationString)
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextSecondary)
                if session.progressRatio > 1.0 {
                    Text("+\(Int((session.progressRatio - 1.0) * 100))%")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmWarning)
                }
                if !session.nudges.isEmpty {
                    Text("\(session.nudges.count) nudge\(session.nudges.count == 1 ? "" : "s")")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmMauve)
                }
            }
        }
        .padding(.vertical, CMSpacing.xs)
    }
}

private struct SessionEditSheet: View {
    let store: DriftStore
    let session: WorkSession
    let onDismiss: () -> Void

    @State private var taskName: String
    @State private var estimateMinutes: Int

    init(store: DriftStore, session: WorkSession, onDismiss: @escaping () -> Void) {
        self.store = store
        self.session = session
        self.onDismiss = onDismiss
        _taskName = State(initialValue: session.taskName)
        _estimateMinutes = State(initialValue: session.estimateMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CMSpacing.lg) {
            Text("Edit Session")
                .font(CMFont.heading)

            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                Text("TASK NAME")
                    .font(CMFont.sectionHeader)
                    .foregroundStyle(Color.cmTextTertiary)
                    .tracking(CMTracking.header)
                TextField("Task name", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(CMFont.body)
                    .padding(CMSpacing.sm)
                    .background(Color.cmSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                Text("ESTIMATE")
                    .font(CMFont.sectionHeader)
                    .foregroundStyle(Color.cmTextTertiary)
                    .tracking(CMTracking.header)
                Stepper(estimateLabel, value: $estimateMinutes, in: 15...480, step: 15)
                    .font(CMFont.monoBody)
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    store.renameSession(id: session.id, newName: taskName)
                    store.updateEstimate(id: session.id, minutes: estimateMinutes)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(CMSpacing.lg)
        .frame(width: 340)
        .background(Color.cmSurface)
        .preferredColorScheme(.dark)
    }

    private var estimateLabel: String {
        let h = estimateMinutes / 60, m = estimateMinutes % 60
        return h > 0 ? (m > 0 ? "\(h)h \(m)m" : "\(h)h") : "\(m)m"
    }
}

// MARK: - Settings Panel

private struct SettingsPanel: View {
    @Bindable var store: DriftStore
    @Bindable var settings: DriftSettings
    let titlebarHeight: CGFloat

    @State private var editingPattern: Pattern?
    @State private var showClearConfirm = false
    @State private var exportURL: URL?
    @State private var showExportError = false
    @State private var showImportPicker = false
    @State private var importCount: Int?

    static var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CMSpacing.lg) {

                Text("Settings")
                    .font(CMFont.heading)
                    .foregroundStyle(Color.cmTextPrimary)

                // -- General --
                settingsGroup("General") {
                    hotkeyRow
                    Divider().opacity(0.15)
                    settingsRow("Elapsed time in menu bar") {
                        Toggle("", isOn: $settings.showElapsedInMenuBar)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                // -- Alerts --
                settingsGroup("Alerts") {
                    settingsRow("Sound on nudge") {
                        Toggle("", isOn: $settings.playSoundOnNudge)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    Divider().opacity(0.15)
                    settingsRow("Auto-open popover") {
                        Toggle("", isOn: $settings.autoOpenOnNudge)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    if settings.autoOpenOnNudge {
                        settingsRow("Delay") {
                            Stepper("\(settings.autoOpenDelaySeconds)s", value: $settings.autoOpenDelaySeconds, in: 15...300, step: 15)
                                .font(CMFont.monoBody)
                                .fixedSize()
                        }
                    }
                    Divider().opacity(0.15)
                    settingsRow("Snooze duration") {
                        Stepper("\(settings.snoozeDurationMinutes) min", value: $settings.snoozeDurationMinutes, in: 5...120, step: 5)
                            .font(CMFont.monoBody)
                            .fixedSize()
                    }
                }

                // -- Patterns --
                settingsGroup("Patterns") {
                    ForEach(store.patterns) { pattern in
                        if pattern != store.patterns.first {
                            Divider().opacity(0.15)
                        }
                        patternRow(pattern)
                    }
                    Divider().opacity(0.15)
                    HStack {
                        Spacer()
                        Button("Reset to Defaults") {
                            store.resetPatternsToDefaults()
                        }
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmWarning)
                        .buttonStyle(.plain)
                    }
                }

                // -- Data --
                settingsGroup("Data") {
                    HStack(spacing: CMSpacing.lg) {
                        stat("Sessions", "\(store.sessions.count)")
                        stat("Nudges", "\(store.patterns.reduce(0) { $0 + $1.fireCount })")
                        stat("Heed Rate", heedRate)
                    }
                    Divider().opacity(0.15)
                    HStack(spacing: CMSpacing.sm) {
                        Button("Export") {
                            if let url = store.exportData() {
                                exportURL = url
                            } else {
                                showExportError = true
                            }
                        }
                        .buttonStyle(.bordered)
                        Button("Import") { showImportPicker = true }
                            .buttonStyle(.bordered)
                        if let url = exportURL {
                            Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                .font(CMFont.mono)
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.cmAccent)
                        }
                        if let count = importCount {
                            Text("\(count) imported")
                                .font(CMFont.mono)
                                .foregroundStyle(Color.cmGreen)
                        }
                        Spacer()
                        Button("Clear\u{2026}") { showClearConfirm = true }
                            .buttonStyle(.bordered)
                            .tint(Color.cmError)
                    }
                }

                // About
                HStack {
                    Text("Drift \(Self.versionString)")
                        .font(CMFont.mono)
                        .foregroundStyle(Color.cmTextTertiary)
                    Spacer()
                    Button("Check for Updates") {
                        if let delegate = NSApp.delegate as? AppDelegate {
                            delegate.updaterController.checkForUpdates(nil)
                        }
                    }
                    .font(CMFont.mono)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.cmAccent)
                }
            }
            .padding(.top, titlebarHeight + CMSpacing.md)
            .padding(.horizontal, CMSpacing.lg)
            .padding(.bottom, CMSpacing.lg)
        }
        .alert("Clear All Sessions?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) { store.clearAllSessions() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes all \(store.sessions.count) sessions. Pattern stats are preserved.")
        }
        .sheet(item: $editingPattern) { pattern in
            PatternEditSheet(store: store, pattern: pattern) { editingPattern = nil }
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not write session data. Check disk space and permissions.")
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let count = store.importData(from: url)
                importCount = count
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importCount = nil }
            }
        }
    }

    // MARK: - Hotkey row

    private var hotkeyRow: some View {
        HStack {
            Text("Shortcut")
                .font(CMFont.body)
                .foregroundStyle(Color.cmTextPrimary)
            Spacer()
            HotkeyRecorderView(settings: settings)
        }
        .padding(.vertical, CMSpacing.xs)
    }

    // MARK: - Builders

    @ViewBuilder
    private func settingsGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CMSpacing.sm) {
            Text(title.uppercased())
                .font(CMFont.sectionHeader)
                .foregroundStyle(Color.cmTextTertiary)
                .tracking(CMTracking.header)
            GlassCard { content() }
        }
    }

    @ViewBuilder
    private func settingsRow(_ label: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(CMFont.body)
                .foregroundStyle(Color.cmTextPrimary)
            Spacer()
            trailing()
        }
        .padding(.vertical, CMSpacing.xs)
    }

    @ViewBuilder
    private func patternRow(_ pattern: Pattern) -> some View {
        HStack(alignment: .top, spacing: CMSpacing.sm) {
            Circle()
                .fill(pattern.isEnabled ? dotColor(for: pattern) : Color.cmTextTertiary)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(pattern.name)
                    .font(CMFont.itemTitle)
                    .foregroundStyle(pattern.isEnabled ? Color.cmTextPrimary : Color.cmTextTertiary)
                Text(pattern.description)
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
                    .lineLimit(2)
                HStack(spacing: CMSpacing.sm) {
                    Text(thresholdLabel(for: pattern))
                    Text("\u{00B7}")
                    Text(pattern.fireCount == 0 ? "no fires" : "\(pattern.fireCount)F  \(pattern.heededCount)H  \(pattern.dismissedCount)D")
                }
                .font(CMFont.mono)
                .foregroundStyle(Color.cmTextTertiary)
            }
            Spacer()
            VStack(spacing: CMSpacing.xs) {
                Button { editingPattern = pattern } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cmTextSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Toggle("", isOn: Binding(
                    get: { pattern.isEnabled },
                    set: { _ in store.togglePattern(id: pattern.id) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
        .padding(.vertical, CMSpacing.xs)
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CMFont.mono)
                .foregroundStyle(Color.cmTextTertiary)
            Text(value)
                .font(CMFont.monoBody)
                .foregroundStyle(Color.cmTextPrimary)
        }
    }

    // MARK: - Helpers

    private func dotColor(for pattern: Pattern) -> Color {
        switch pattern.triggerType {
        case .scopeCreep:        return Color.cmWarning
        case .infrastructureFirst: return Color.cmAccent
        case .boredom:           return Color.cmMauve
        }
    }

    private func thresholdLabel(for pattern: Pattern) -> String {
        switch pattern.triggerType {
        case .scopeCreep:     return "\(String(format: "%.1f", pattern.thresholdMultiplier))\u{00D7} est"
        case .infrastructureFirst: return "4h infra"
        case .boredom:        return "3h any"
        }
    }

    private var heedRate: String {
        let f = store.patterns.reduce(0) { $0 + $1.fireCount }
        let h = store.patterns.reduce(0) { $0 + $1.heededCount }
        guard f > 0 else { return "--" }
        return "\(Int(Double(h) / Double(f) * 100))%"
    }
}

// MARK: - Pattern Edit Sheet (with +/- stepper — NA-3 fix)

private struct PatternEditSheet: View {
    let store: DriftStore
    let pattern: Pattern
    let onDismiss: () -> Void

    @State private var multiplier: Double
    @State private var messageTemplate: String

    init(store: DriftStore, pattern: Pattern, onDismiss: @escaping () -> Void) {
        self.store = store
        self.pattern = pattern
        self.onDismiss = onDismiss
        _multiplier = State(initialValue: pattern.thresholdMultiplier)
        _messageTemplate = State(initialValue: pattern.messageTemplate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CMSpacing.lg) {
            Text("Edit \(pattern.name)")
                .font(CMFont.heading)

            if pattern.triggerType == .scopeCreep {
                VStack(alignment: .leading, spacing: CMSpacing.xs) {
                    Text("THRESHOLD")
                        .font(CMFont.sectionHeader)
                        .foregroundStyle(Color.cmTextTertiary)
                        .tracking(CMTracking.header)
                    HStack(spacing: CMSpacing.sm) {
                        Button(action: { multiplier = max(1.0, multiplier - 0.5) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(Color.cmSurfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(multiplier <= 1.0 ? Color.cmTextTertiary : Color.cmTextSecondary)
                        .disabled(multiplier <= 1.0)

                        Slider(value: $multiplier, in: 1.0...5.0, step: 0.5)

                        Button(action: { multiplier = min(5.0, multiplier + 0.5) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(Color.cmSurfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(multiplier >= 5.0 ? Color.cmTextTertiary : Color.cmTextSecondary)
                        .disabled(multiplier >= 5.0)

                        Text("\(String(format: "%.1f", multiplier))\u{00D7}")
                            .font(CMFont.monoBody)
                            .foregroundStyle(Color.cmTextPrimary)
                            .frame(width: 36)
                    }
                }
            }

            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                Text("NUDGE MESSAGE")
                    .font(CMFont.sectionHeader)
                    .foregroundStyle(Color.cmTextTertiary)
                    .tracking(CMTracking.header)
                TextEditor(text: $messageTemplate)
                    .font(CMFont.body)
                    .scrollContentBackground(.hidden)
                    .padding(CMSpacing.sm)
                    .background(Color.cmSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(height: 90)
                Text("{elapsed} and {estimate} are placeholders")
                    .font(CMFont.mono)
                    .foregroundStyle(Color.cmTextTertiary)
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    store.updatePatternThreshold(id: pattern.id, multiplier: multiplier)
                    store.updatePatternMessage(id: pattern.id, template: messageTemplate)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(CMSpacing.lg)
        .frame(width: 380)
        .background(Color.cmSurface)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CMSpacing.xs) {
            content
        }
        .padding(.horizontal, CMSpacing.md)
        .padding(.vertical, CMSpacing.sm + 2)
        .background(Color.cmSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.cmBorder.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Pattern Equatable (for ForEach identity checks)

extension Pattern: Equatable {
    static func == (lhs: Pattern, rhs: Pattern) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    DriftWindowView(
        store: DriftStore(),
        engine: PatternEngine(store: DriftStore()),
        settings: DriftSettings()
    )
    .frame(width: 560, height: 580)
}
