// NudgeRecord.swift
// A single nudge event within a WorkSession — records when it fired and how the user responded.

import Foundation

// MARK: - Nudge response

/// How the user responded to a nudge card.
enum NudgeResponse: String, Codable {
    /// User acknowledged and committed to course-correcting.
    case acknowledged = "acknowledged"
    /// User dismissed — pattern won't re-fire this session.
    case dismissed    = "dismissed"
    /// User snoozed — pattern re-evaluates after 30 minutes.
    case snoozed      = "snoozed"
}

// MARK: - NudgeRecord

struct NudgeRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let patternId: UUID
    let firedAt: Date
    /// nil until the user interacts with the nudge card.
    var response: NudgeResponse?
    var respondedAt: Date?

    /// The rendered message shown to the user at fire time.
    var renderedMessage: String

    /// Which fire this was for this pattern this session (1 = initial, 2 = snooze re-fire).
    var fireIndex: Int

    init(
        id: UUID = UUID(),
        patternId: UUID,
        firedAt: Date = Date(),
        response: NudgeResponse? = nil,
        respondedAt: Date? = nil,
        renderedMessage: String,
        fireIndex: Int = 1
    ) {
        self.id = id
        self.patternId = patternId
        self.firedAt = firedAt
        self.response = response
        self.respondedAt = respondedAt
        self.renderedMessage = renderedMessage
        self.fireIndex = fireIndex
    }

    /// True when this nudge is waiting for a user response.
    var isPending: Bool { response == nil }
}
