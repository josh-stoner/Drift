// PopoverRoot.swift
// Routes between idle, start-session, active, nudge, and retrospective states.

import SwiftUI

enum PopoverRoute {
    case onboarding, idle, startSession, active, nudge, retrospective, sessionSummary
}

struct PopoverRoot: View {
    @Environment(DriftStore.self) private var store
    var engine: PatternEngine

    @State private var route: PopoverRoute = .idle
    @State private var showStaleWarning: Bool = false
    @State private var completedSession: WorkSession?

    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    var body: some View {
        ZStack {
            Color.cmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                switch route {
                case .onboarding:
                    OnboardingView {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        withAnimation(.cmDefault) { route = .idle }
                    }
                    .transition(.opacity)

                case .idle:
                    IdleView(
                        store: store,
                        onStartSession: { withAnimation(.cmDefault) { route = .startSession } },
                        onShowRetro: { withAnimation(.cmDefault) { route = .retrospective } }
                    )
                    .transition(.opacity)

                case .startSession:
                    StartSessionView(
                        store: store,
                        engine: engine,
                        onStarted: { withAnimation(.cmDefault) { route = .active } },
                        onCancel: { withAnimation(.cmDefault) { route = .idle } }
                    )
                    .transition(.opacity)

                case .active:
                    ActiveSessionView(
                        store: store,
                        engine: engine,
                        onEndSession: {
                            // Capture session before ending for summary
                            if var session = store.activeSession {
                                session.endedAt = Date()
                                completedSession = session
                            }
                            engine.sessionDidEnd()
                            store.endSession()
                            withAnimation(.cmDefault) { route = .sessionSummary }
                        },
                        onShowRetro: { withAnimation(.cmDefault) { route = .retrospective } }
                    )
                    .transition(.opacity)

                case .nudge:
                    NudgeView(engine: engine, onResponded: { withAnimation(.cmDefault) { route = .active } })
                        .transition(.opacity)

                case .sessionSummary:
                    if let session = completedSession {
                        SessionSummaryView(session: session) {
                            completedSession = nil
                            withAnimation(.cmDefault) { route = .idle }
                        }
                        .transition(.opacity)
                    } else {
                        IdleView(store: store, onStartSession: { withAnimation(.cmDefault) { route = .startSession } }, onShowRetro: { withAnimation(.cmDefault) { route = .retrospective } })
                            .transition(.opacity)
                    }

                case .retrospective:
                    RetrospectiveView(
                        store: store,
                        onBack: {
                            withAnimation(.cmDefault) {
                                route = store.activeSession != nil ? .active : .idle
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
        }
        .frame(width: 340)
        .frame(minHeight: heightForRoute)
        .animation(.cmDefault, value: route)
        .preferredColorScheme(.dark)
        .onAppear {
            if isFirstLaunch { route = .onboarding; return }
            syncRoute(); checkStaleSession()
        }
        .onChange(of: store.activeSession?.id) { _, _ in syncRoute() }
        .onChange(of: engine.pendingNudge?.nudge.id) { _, newId in
            if newId != nil { route = .nudge }
        }
        .overlay(alignment: .top) {
            if showStaleWarning, let session = store.activeSession {
                StaleSessionBanner(
                    session: session,
                    onEndSession: {
                        showStaleWarning = false
                        engine.sessionDidEnd()
                        store.endSession()
                        route = .idle
                    },
                    onKeepRunning: { showStaleWarning = false }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.cmDefault, value: showStaleWarning)
    }

    /// Prioritized route sync: nudge > active > idle.
    /// When both store.activeSession and engine.pendingNudge change on the same tick,
    /// pendingNudge takes priority (nudge route). The onChange watchers guarantee:
    /// pendingNudge fires → onChange → route = .nudge immediately.
    /// sessionSummary is never overridden — user must dismiss manually.
    private func syncRoute() {
        if let _ = engine.pendingNudge, store.activeSession != nil {
            route = .nudge
        } else if store.activeSession != nil {
            if route == .idle || route == .startSession { route = .active }
        } else {
            // Don't override summary view — let user dismiss it manually
            if route == .sessionSummary { return }
            if route == .active || route == .nudge || route == .startSession { route = .idle }
        }
    }

    private func checkStaleSession() {
        if let session = store.activeSession, session.isStale { showStaleWarning = true }
    }

    private var heightForRoute: CGFloat {
        switch route {
        case .onboarding:     return 300
        case .idle:           return 220
        case .startSession:   return 260
        case .active:         return 280
        case .nudge:          return 350
        case .retrospective:  return 380
        case .sessionSummary: return 300
        }
    }
}

// MARK: - Stale session banner

private struct StaleSessionBanner: View {
    let session: WorkSession
    let onEndSession: () -> Void
    let onKeepRunning: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CMSpacing.sm) {
            Text("Session still active \u{2014} \(session.durationString)")
                .font(CMFont.itemTitle)
                .foregroundStyle(Color.cmWarning)
            Text("Did you mean to end this?")
                .font(CMFont.body)
                .foregroundStyle(Color.cmTextSecondary)
            HStack(spacing: CMSpacing.sm) {
                Button("End Session") { onEndSession() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                Button("Keep Running") { onKeepRunning() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.cmTextSecondary)
            }
        }
        .padding(CMSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cmSurface)
    }
}
