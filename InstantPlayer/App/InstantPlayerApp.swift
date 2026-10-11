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
    /// Container created once per app instance; zero work beyond
    /// allocation-only construction (design §6, §7.3 — the launch-path
    /// additions are exactly two allocations: the repository actor here
    /// and the `FeedViewModel` when `RootView` appears).
    @State private var dependencies = AppDependencies()

    /// Close-quits lifecycle policy (E2-S2, design §6.1 — S8): the adaptor
    /// is the termination policy ONLY. D18's adaptor reservation for
    /// *entry routing* stays deliberately unbuilt (RootView's note stands
    /// — a divergence would be a coordinator escalation, not built here).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // One `Window` on purpose (E2-S1, design §3.4): one window owns the
        // one `RootView`, the one `FeedViewModel`, the one state machine —
        // the precondition for "one entry action routed once" (S1–S7).
        // R37–R40's window behaviors remain E2-S2's work.
        Window("InstantPlayer", id: "main") {
            RootView(dependencies: dependencies)
        }
    }
}
