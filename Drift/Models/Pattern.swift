// Pattern.swift
// A behavioral failure-mode template that the engine evaluates against the active session.
// Pre-loaded patterns live in DriftStore.defaultPatterns — user cannot add/remove in MVP.

import Foundation

// MARK: - Trigger type

/// Describes which evaluation logic fires the pattern.
enum TriggerType: String, Codable, CaseIterable {
    /// Fires when elapsed time exceeds estimate × thresholdMultiplier.
    case scopeCreep       = "scopeCreep"
    /// Fires when elapsed > 4 hours AND task name contains infrastructure keywords.
    case infrastructureFirst = "infrastructureFirst"
    /// Fires when elapsed > 3 hours (simple time gate).
    case boredom          = "boredom"
}

// MARK: - Pattern

struct Pattern: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var triggerType: TriggerType
    /// Only used by scopeCreep — multiplier applied to estimateMinutes.
    var thresholdMultiplier: Double
    /// Raw message template. Placeholders: {elapsed}, {estimate}.
    var messageTemplate: String

    /// Whether this pattern is active. Disabled patterns are skipped during evaluation.
    var isEnabled: Bool

    // Lifetime stats across all sessions
    var fireCount: Int
    var heededCount: Int
    var dismissedCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        triggerType: TriggerType,
        thresholdMultiplier: Double = 2.0,
        messageTemplate: String,
        isEnabled: Bool = true,
        fireCount: Int = 0,
        heededCount: Int = 0,
        dismissedCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.triggerType = triggerType
        self.thresholdMultiplier = thresholdMultiplier
        self.messageTemplate = messageTemplate
        self.isEnabled = isEnabled
        self.fireCount = fireCount
        self.heededCount = heededCount
        self.dismissedCount = dismissedCount
    }

    // MARK: - Codable (backward-compatible — isEnabled defaults to true for old JSON)

    enum CodingKeys: String, CodingKey {
        case id, name, description, triggerType, thresholdMultiplier, messageTemplate
        case isEnabled, fireCount, heededCount, dismissedCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        triggerType = try c.decode(TriggerType.self, forKey: .triggerType)
        thresholdMultiplier = try c.decode(Double.self, forKey: .thresholdMultiplier)
        messageTemplate = try c.decode(String.self, forKey: .messageTemplate)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        fireCount = try c.decode(Int.self, forKey: .fireCount)
        heededCount = try c.decode(Int.self, forKey: .heededCount)
        dismissedCount = try c.decode(Int.self, forKey: .dismissedCount)
    }

    // MARK: - Message rendering

    /// Replace {elapsed} and {estimate} placeholders with formatted durations.
    func renderedMessage(elapsed: TimeInterval, estimateMinutes: Int) -> String {
        let elapsedStr  = TimeInterval.formatElapsed(elapsed)
        let estimateStr = TimeInterval.formatElapsed(TimeInterval(estimateMinutes) * 60)
        return messageTemplate
            .replacingOccurrences(of: "{elapsed}", with: elapsedStr)
            .replacingOccurrences(of: "{estimate}", with: estimateStr)
    }

    // MARK: - Threshold display

    /// Human-readable threshold description shown in active session pattern rows.
    func thresholdDescription(estimateMinutes: Int) -> String {
        switch triggerType {
        case .scopeCreep:
            let thresholdSeconds = TimeInterval(estimateMinutes) * 60 * thresholdMultiplier
            return "Fires at \(TimeInterval.formatElapsed(thresholdSeconds))"
        case .infrastructureFirst:
            return "Fires at 4h (infra keywords)"
        case .boredom:
            return "Fires at 3h"
        }
    }
}

// MARK: - Infrastructure keyword list

extension Pattern {
    static let infrastructureKeywords: [String] = [
        "setup", "infra", "scaffold", "config", "configuration",
        "architecture", "arch", "boilerplate", "bootstrap", "init",
        "initialize", "foundation", "pipeline", "tooling", "ci", "cd",
        "devops", "deploy", "deployment", "infrastructure"
    ]
}

// MARK: - TimeInterval formatting helper

extension TimeInterval {
    /// Format as "1h 23m" or "45m" for display in nudge messages and UI.
    static func formatElapsed(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
