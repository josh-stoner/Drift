// PatternEngine.swift
// Evaluates patterns against the active session on a 60-second tick.
// Fires nudges, manages snooze timers, controls menu bar icon state,
// and auto-opens the popover when a nudge has gone unacknowledged for 60 seconds.

import Foundation
import Observation
import Combine
import AppKit
import UserNotifications

// MARK: - Menu bar icon state

/// Drives the menu bar icon color token.
enum MenuBarState {
    case idle       // No session — dim tertiary
    case active     // Session running — accent blue
    case nudgePending // Pattern fired — Mauve
    case overrun    // Elapsed > estimate — amber warning
}

// MARK: - PatternEngine

@Observable
final class PatternEngine {

    // MARK: - Published state

    /// Current icon/color state for the menu bar button.
    var menuBarState: MenuBarState = .idle

    /// Nudge waiting for user response, if any.
    var pendingNudge: (pattern: Pattern, nudge: NudgeRecord)?

    /// True when the engine wants the popover to open automatically.
    var shouldAutoOpenPopover: Bool = false

    // MARK: - Private state

    private let store: DriftStore
    let settings: DriftSettings

    /// Tracks which patterns have fired this session and their disposition.
    /// Key: patternId, Value: SessionPatternState
    private var sessionPatternState: [UUID: SessionPatternState] = [:]

    /// Cancellables for the 60-second evaluation timer.
    private var timerCancellable: AnyCancellable?

    /// Timer for auto-opening popover after configurable delay.
    private var autoOpenCancellable: AnyCancellable?

    // MARK: - Init

    init(store: DriftStore, settings: DriftSettings = DriftSettings()) {
        self.store = store
        self.settings = settings
        startTimer()
        requestNotificationPermission()
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    // MARK: - Tick

    /// Called every 60 seconds. Evaluates all patterns and updates state.
    func tick() {
        guard let session = store.activeSession else {
            resetToIdle()
            return
        }

        let elapsed = session.elapsed

        for pattern in store.patterns {
            evaluatePattern(pattern, session: session, elapsed: elapsed)
        }

        updateMenuBarState(session: session, elapsed: elapsed)
    }

    // MARK: - Pattern evaluation

    private func evaluatePattern(_ pattern: Pattern, session: WorkSession, elapsed: TimeInterval) {
        // Skip disabled patterns
        guard pattern.isEnabled else { return }

        let state = sessionPatternState[pattern.id] ?? SessionPatternState()

        // Skip if this pattern has fired max times (2) or is permanently suppressed
        guard !state.isSuppressed else { return }
        guard state.fireCount < 2 else { return }

        // Check snooze — if snoozed, only re-evaluate after 30 minutes
        if let snoozeUntil = state.snoozedUntil, Date() < snoozeUntil {
            return
        }

        // Evaluate trigger condition
        guard shouldFire(pattern: pattern, session: session, elapsed: elapsed) else { return }

        // Don't fire again if we just fired and are waiting for a response
        if pendingNudge?.pattern.id == pattern.id { return }

        // Fire the nudge
        var state2 = sessionPatternState[pattern.id] ?? SessionPatternState()
        fireNudge(pattern: pattern, session: session, elapsed: elapsed, state: &state2)
        sessionPatternState[pattern.id] = state2
    }

    private func shouldFire(pattern: Pattern, session: WorkSession, elapsed: TimeInterval) -> Bool {
        switch pattern.triggerType {
        case .scopeCreep:
            let threshold = session.estimateInterval * pattern.thresholdMultiplier
            return elapsed > threshold

        case .infrastructureFirst:
            let fourHours: TimeInterval = 4 * 3600
            guard elapsed > fourHours else { return false }
            let taskLower = session.taskName.lowercased()
            return Pattern.infrastructureKeywords.contains { taskLower.contains($0) }

        case .boredom:
            let threeHours: TimeInterval = 3 * 3600
            return elapsed > threeHours
        }
    }

    private func fireNudge(
        pattern: Pattern,
        session: WorkSession,
        elapsed: TimeInterval,
        state: inout SessionPatternState
    ) {
        let message = pattern.renderedMessage(
            elapsed: elapsed,
            estimateMinutes: session.estimateMinutes
        )
        let nudge = NudgeRecord(
            patternId: pattern.id,
            renderedMessage: message,
            fireIndex: state.fireCount + 1
        )

        state.fireCount += 1

        store.recordNudge(nudge)

        // Set pending nudge and icon state
        pendingNudge = (pattern: pattern, nudge: nudge)
        menuBarState = .nudgePending

        // Play alert sound if enabled
        if settings.playSoundOnNudge {
            NSSound(named: "Purr")?.play()
        }

        // System notification
        sendNotification(pattern: pattern, message: message)

        // Schedule auto-open after configurable delay
        if settings.autoOpenOnNudge {
            scheduleAutoOpen()
        }
    }

    // MARK: - Response handling

    /// Called by the UI when the user responds to the pending nudge card.
    func respondToPendingNudge(response: NudgeResponse) {
        guard let pending = pendingNudge else { return }

        cancelAutoOpen()
        store.respondToNudge(id: pending.nudge.id, response: response)

        switch response {
        case .acknowledged, .dismissed:
            // Suppress this pattern for the rest of the session
            var s = sessionPatternState[pending.pattern.id] ?? SessionPatternState()
            s.isSuppressed = true
            sessionPatternState[pending.pattern.id] = s

        case .snoozed:
            // Re-evaluate after configurable snooze duration
            var s = sessionPatternState[pending.pattern.id] ?? SessionPatternState()
            s.snoozedUntil = Date().addingTimeInterval(TimeInterval(settings.snoozeDurationMinutes) * 60)
            sessionPatternState[pending.pattern.id] = s
        }

        pendingNudge = nil
        updateMenuBarState(
            session: store.activeSession,
            elapsed: store.activeSession?.elapsed ?? 0
        )
    }

    // MARK: - Session lifecycle

    /// Call when a new session starts — resets per-session pattern state.
    func sessionDidStart() {
        sessionPatternState = [:]
        pendingNudge = nil
        cancelAutoOpen()
        menuBarState = .active
    }

    /// Call when the session ends.
    func sessionDidEnd() {
        sessionPatternState = [:]
        pendingNudge = nil
        cancelAutoOpen()
        menuBarState = .idle
    }

    // MARK: - Auto-open popover

    private func scheduleAutoOpen() {
        cancelAutoOpen()
        let delay = TimeInterval(settings.autoOpenDelaySeconds)
        autoOpenCancellable = Timer.publish(every: delay, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                guard let self, self.pendingNudge != nil else { return }
                self.shouldAutoOpenPopover = true
            }
    }

    private func cancelAutoOpen() {
        autoOpenCancellable = nil
        shouldAutoOpenPopover = false
    }

    // MARK: - Menu bar state update

    private func updateMenuBarState(session: WorkSession?, elapsed: TimeInterval) {
        guard let session else {
            menuBarState = .idle
            return
        }

        if pendingNudge != nil {
            menuBarState = .nudgePending
        } else if elapsed > session.estimateInterval * 1.5 {
            menuBarState = .overrun
        } else {
            menuBarState = .active
        }
    }

    private func resetToIdle() {
        menuBarState = .idle
        sessionPatternState = [:]
        pendingNudge = nil
        cancelAutoOpen()
    }

    // MARK: - Pattern status for UI

    /// Progress description for a pattern row in the active session view.
    func statusDescription(for pattern: Pattern, session: WorkSession) -> String {
        let elapsed = session.elapsed
        let state = sessionPatternState[pattern.id] ?? SessionPatternState()

        if state.isSuppressed {
            return "Done this session"
        }
        if let snoozeUntil = state.snoozedUntil, Date() < snoozeUntil {
            let remaining = snoozeUntil.timeIntervalSinceNow
            return "Snoozed · \(TimeInterval.formatElapsed(remaining)) left"
        }

        switch pattern.triggerType {
        case .scopeCreep:
            let threshold = session.estimateInterval * pattern.thresholdMultiplier
            let elapsedStr = TimeInterval.formatElapsed(elapsed)
            let thresholdStr = TimeInterval.formatElapsed(threshold)
            return "Fires at \(thresholdStr) · you're at \(elapsedStr)"

        case .infrastructureFirst:
            let elapsedStr = TimeInterval.formatElapsed(elapsed)
            return "Fires at 4h (infra) · you're at \(elapsedStr)"

        case .boredom:
            let elapsedStr = TimeInterval.formatElapsed(elapsed)
            return "Fires at 3h · you're at \(elapsedStr)"
        }
    }

    /// Whether a pattern has already fired this session.
    func hasFired(patternId: UUID) -> Bool {
        (sessionPatternState[patternId]?.fireCount ?? 0) > 0
    }

    // MARK: - System notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(pattern: Pattern, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Drift \u{2014} \(pattern.name)"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "drift-nudge-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Per-session pattern tracking

private struct SessionPatternState {
    var fireCount: Int = 0
    var isSuppressed: Bool = false
    var snoozedUntil: Date? = nil
}

