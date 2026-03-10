// DriftStore.swift
// @Observable JSON persistence layer — all Drift state lives here.
// Reads and writes to ~/Library/Application Support/Drift/.
// Save is called explicitly after every meaningful state change.

import Foundation
import Observation

@Observable
final class DriftStore {

    // MARK: - State

    /// All known patterns (3 pre-loaded, order preserved).
    var patterns: [Pattern] = []

    /// Historical sessions, newest first.
    var sessions: [WorkSession] = []

    /// The session currently in progress, if any.
    var activeSession: WorkSession?

    // MARK: - Persistence

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var appSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Drift", isDirectory: true)
    }

    private var patternsURL: URL  { appSupportURL.appendingPathComponent("patterns.json") }
    private var sessionsURL: URL  { appSupportURL.appendingPathComponent("sessions.json") }
    private var activeURL: URL    { appSupportURL.appendingPathComponent("active_session.json") }

    // MARK: - Init

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        createDirectoryIfNeeded()
        load()
    }

    // MARK: - Load

    private func load() {
        // Load patterns — seed defaults if no file exists yet
        if let saved: [Pattern] = loadJSON(from: patternsURL) {
            patterns = saved
        } else {
            patterns = DriftStore.defaultPatterns
            savePatterns()
        }

        sessions      = loadJSON(from: sessionsURL) ?? []
        activeSession = loadJSON(from: activeURL)
    }

    private func loadJSON<T: Decodable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[DriftStore] Failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Save

    func save() {
        savePatterns()
        saveSessions()
        saveActiveSession()
    }

    private func savePatterns() {
        saveJSON(patterns, to: patternsURL)
    }

    private func saveSessions() {
        saveJSON(sessions, to: sessionsURL)
    }

    private func saveActiveSession() {
        if let session = activeSession {
            saveJSON(session, to: activeURL)
        } else {
            try? FileManager.default.removeItem(at: activeURL)
        }
    }

    private func saveJSON<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomicWrite)
        } catch {
            print("[DriftStore] Failed to save \(url.lastPathComponent): \(error)")
        }
    }

    // MARK: - Session management

    /// Begin a new session; persists immediately.
    func startSession(taskName: String, estimateMinutes: Int) {
        let session = WorkSession(
            taskName: taskName,
            estimateMinutes: estimateMinutes
        )
        activeSession = session
        saveActiveSession()
    }

    /// End the active session, move it to history.
    func endSession() {
        guard var session = activeSession else { return }
        session.endedAt = Date()
        sessions.insert(session, at: 0)
        activeSession = nil
        saveSessions()
        saveActiveSession()
        autoBackup()
    }

    /// Writes a timestamped backup of sessions.json to the backups/ subfolder.
    /// Keeps the 10 most recent backups and removes older ones.
    private func autoBackup() {
        let backupDir = appSupportURL.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        let name = "sessions-\(fmt.string(from: Date())).json"
        let dest = backupDir.appendingPathComponent(name)

        if let data = try? encoder.encode(sessions) {
            try? data.write(to: dest, options: .atomicWrite)
        }

        // Prune old backups — keep 10 most recent
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey])
            .sorted(by: { ($0.lastPathComponent) > ($1.lastPathComponent) }) {
            for file in files.dropFirst(10) {
                try? fm.removeItem(at: file)
            }
        }
    }

    // MARK: - Session editing

    /// Rename an existing session's task.
    func renameSession(id: UUID, newName: String) {
        if var active = activeSession, active.id == id {
            active.taskName = newName
            activeSession = active
            saveActiveSession()
            return
        }
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].taskName = newName
            saveSessions()
        }
    }

    /// Update estimate on an existing session.
    func updateEstimate(id: UUID, minutes: Int) {
        if var active = activeSession, active.id == id {
            active.estimateMinutes = minutes
            activeSession = active
            saveActiveSession()
            return
        }
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].estimateMinutes = minutes
            saveSessions()
        }
    }

    /// Delete a session from history.
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        saveSessions()
    }

    /// Delete multiple sessions.
    func deleteSessions(ids: Set<UUID>) {
        sessions.removeAll { ids.contains($0.id) }
        saveSessions()
    }

    /// Clear all session history.
    func clearAllSessions() {
        sessions.removeAll()
        saveSessions()
    }

    /// Export all data as JSON to a temporary file and return its URL.
    func exportData() -> URL? {
        struct ExportPayload: Encodable {
            let exportedAt: Date
            let patterns: [Pattern]
            let sessions: [WorkSession]
            let activeSession: WorkSession?
        }
        let payload = ExportPayload(
            exportedAt: Date(),
            patterns: patterns,
            sessions: sessions,
            activeSession: activeSession
        )
        let exportEncoder = JSONEncoder()
        exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        exportEncoder.dateEncodingStrategy = .iso8601
        do {
            let data = try exportEncoder.encode(payload)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd_HHmmss"
            let filename = "drift-export-\(fmt.string(from: Date())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomicWrite)
            return url
        } catch {
            print("[DriftStore] Export failed: \(error)")
            return nil
        }
    }

    // MARK: - Import

    /// Import sessions from a previously exported JSON file. Returns count of imported sessions.
    func importData(from url: URL) -> Int {
        struct ImportPayload: Decodable {
            let sessions: [WorkSession]
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try decoder.decode(ImportPayload.self, from: data)
            let existingIds = Set(sessions.map(\.id))
            let newSessions = payload.sessions.filter { !existingIds.contains($0.id) }
            sessions.insert(contentsOf: newSessions, at: 0)
            sessions.sort { ($0.startedAt) > ($1.startedAt) }
            saveSessions()
            return newSessions.count
        } catch {
            print("[DriftStore] Import failed: \(error)")
            return 0
        }
    }

    // MARK: - Pattern editing

    /// Update a pattern's threshold multiplier.
    func updatePatternThreshold(id: UUID, multiplier: Double) {
        if let idx = patterns.firstIndex(where: { $0.id == id }) {
            patterns[idx].thresholdMultiplier = multiplier
            savePatterns()
        }
    }

    /// Update a pattern's message template.
    func updatePatternMessage(id: UUID, template: String) {
        if let idx = patterns.firstIndex(where: { $0.id == id }) {
            patterns[idx].messageTemplate = template
            savePatterns()
        }
    }

    /// Toggle a pattern's enabled state.
    func togglePattern(id: UUID) {
        if let idx = patterns.firstIndex(where: { $0.id == id }) {
            patterns[idx].isEnabled.toggle()
            savePatterns()
        }
    }

    /// Reset all patterns to defaults (preserves fire stats).
    func resetPatternsToDefaults() {
        let defaults = DriftStore.defaultPatterns
        for i in patterns.indices {
            if let match = defaults.first(where: { $0.triggerType == patterns[i].triggerType }) {
                patterns[i].name = match.name
                patterns[i].description = match.description
                patterns[i].thresholdMultiplier = match.thresholdMultiplier
                patterns[i].messageTemplate = match.messageTemplate
                patterns[i].isEnabled = true
            }
        }
        savePatterns()
    }

    // MARK: - Nudge management

    /// Append a new NudgeRecord to the active session and persist.
    func recordNudge(_ nudge: NudgeRecord) {
        guard activeSession != nil else { return }
        activeSession!.nudges.append(nudge)
        // Increment pattern lifetime fire count
        if let idx = patterns.firstIndex(where: { $0.id == nudge.patternId }) {
            patterns[idx].fireCount += 1
        }
        save()
    }

    /// Update an existing nudge record with the user's response.
    func respondToNudge(id: UUID, response: NudgeResponse) {
        guard activeSession != nil else { return }
        guard let nudgeIdx = activeSession!.nudges.firstIndex(where: { $0.id == id }) else { return }
        activeSession!.nudges[nudgeIdx].response = response
        activeSession!.nudges[nudgeIdx].respondedAt = Date()

        // Update lifetime pattern stats
        if let patternId = activeSession!.nudges[safe: nudgeIdx]?.patternId,
           let patIdx = patterns.firstIndex(where: { $0.id == patternId }) {
            switch response {
            case .acknowledged: patterns[patIdx].heededCount += 1
            case .dismissed:    patterns[patIdx].dismissedCount += 1
            case .snoozed:      break
            }
        }
        save()
    }

    // MARK: - Private helpers

    private func createDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appSupportURL.path) {
            try? fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Default patterns

extension DriftStore {
    static var defaultPatterns: [Pattern] {
        [
            Pattern(
                name: "Scope Creep",
                description: "You're spending significantly more time than you estimated. The instinct to ship something complete is overriding scope discipline.",
                triggerType: .scopeCreep,
                thresholdMultiplier: 2.0,
                messageTemplate: "You're at {elapsed} on a task you scoped for {estimate}. Last time this happened, you hit 15.5 hours on a 1-day task. What's the smallest version you can ship right now?"
            ),
            Pattern(
                name: "Infrastructure First",
                description: "You're deep in setup/infrastructure work. The pattern: ~5 days of infra for 2+ months of leverage. Is this project worth that investment?",
                triggerType: .infrastructureFirst,
                thresholdMultiplier: 2.0,
                messageTemplate: "You're at {elapsed} of infrastructure work. Your pattern: ~5 days infra for 2+ months leverage. Is this a 2-month project, or are you gold-plating?"
            ),
            Pattern(
                name: "Boredom Check",
                description: "You've been on this task a while with no clear progression signal. Redundancy and maintenance kill your engagement within weeks.",
                triggerType: .boredom,
                thresholdMultiplier: 2.0,
                messageTemplate: "You've been at this for {elapsed}. Are you still building something new, or has this become maintenance? Your boredom threshold is real — name what's keeping you engaged."
            )
        ]
    }
}
