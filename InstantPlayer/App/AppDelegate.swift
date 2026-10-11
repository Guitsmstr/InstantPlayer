//
//  AppDelegate.swift
//  InstantPlayer
//
//  App-owned window lifecycle policy (E2-S2, design §6.1 — S8).
//

import AppKit

/// Close-quits policy (E2-S2 design §6.1 — S8): a SwiftUI `Window` scene
/// leaves the app running when its window closes, and no reopen path
/// exists (the in-app picker is a v1 non-goal) — so quitting is the honest
/// single-window behavior. This delegate is the canonical AppKit policy
/// hook: three lines, no window hunting, nothing else. Scene/lifecycle
/// policy is the composition root's business (D10). D18's adaptor
/// reservation for *entry routing* stays deliberately unbuilt — this is
/// the termination policy only (design §6.1).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
