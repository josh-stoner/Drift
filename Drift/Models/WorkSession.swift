// WorkSession.swift
// Represents a single timed work block with associated nudge records.

import Foundation

struct WorkSession: Identifiable, Codable, Hashable {
    let id: UUID
    var taskName: String
    var estimateMinutes: Int
    let startedAt: Date
    var endedAt: Date?
    var nudges: [NudgeRecord]

    init(
        id: UUID = UUID(),
        taskName: String,
        estimateMinutes: Int,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        nudges: [NudgeRecord] = []
    ) {
        self.id = id
        self.taskName = taskName
        self.estimateMinutes = estimateMinutes
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.nudges = nudges
    }

    // MARK: - Derived properties

    /// Elapsed time from start to now (or endedAt if session is closed).
    var elapsed: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    /// Estimate expressed as TimeInterval for comparisons.
    var estimateInterval: TimeInterval {
        TimeInterval(estimateMinutes) * 60
    }

    /// Ratio of elapsed to estimate. 1.0 = on track, >1.0 = overrun.
    var progressRatio: Double {
        guard estimateInterval > 0 else { return 0 }
        return elapsed / estimateInterval
    }

    /// True when this session has been running for 8+ hours with no nudge response.
    var isStale: Bool {
        guard endedAt == nil else { return false }
        let hasRecentResponse = nudges.contains { $0.respondedAt != nil }
        return elapsed >= 8 * 3600 && !hasRecentResponse
    }

    /// Formatted duration string for retrospective display.
    var durationString: String {
        TimeInterval.formatElapsed(elapsed)
    }

    /// Summary of nudge activity for retrospective rows.
    var nudgeSummary: String {
        let count = nudges.count
        if count == 0 { return "No nudges" }
        let heeded = nudges.filter { $0.response == .acknowledged }.count
        return "\(count) nudge\(count == 1 ? "" : "s") · \(heeded) heeded"
    }

    // MARK: - Nudge lookup

    /// All nudge records for a given pattern within this session.
    func nudges(for patternId: UUID) -> [NudgeRecord] {
        nudges.filter { $0.patternId == patternId }
    }

    /// How many times a given pattern has fired this session.
    func fireCount(for patternId: UUID) -> Int {
        nudges(for: patternId).count
    }

    /// The most recent pending nudge, if any.
    var pendingNudge: NudgeRecord? {
        nudges.last { $0.isPending }
    }
}
