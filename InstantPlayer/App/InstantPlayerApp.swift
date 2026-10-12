//
//  InstantPlayerApp.swift
//  InstantPlayer
//
//  App entry + window/scene wiring (E1-S3, design §3.2 — R9, R13;
//  E2-S1, design §3.4 — single window).
//

import SwiftUI

@main
struct InstantPlayerApp: App {
    /// Close-quits lifecycle policy (E2-S2, design §6.1 — S8) and, since
    /// round 4 (evidence §8), the arrow-key monitor: the adaptor is also
    /// the owner of the one composition container (D10) — the same one
    /// `RootView` binds to and the monitor consults (one window, one
    /// model, D18). Container construction stays allocation-only (R13).
    /// D18's adaptor reservation for *entry routing* stays deliberately
    /// unbuilt (RootView's note stands — a divergence would be a
    /// coordinator escalation, not built here).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // One `Window` on purpose (E2-S1, design §3.4): one window owns the
        // one `RootView`, the one `FeedViewModel`, the one state machine —
        // the precondition for "one entry action routed once" (S1–S7).
        // R37–R40's window behaviors remain E2-S2's work.
        Window("InstantPlayer", id: "main") {
            RootView(dependencies: appDelegate.dependencies)
        }
    }
}
