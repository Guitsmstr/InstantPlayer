//
//  AppDelegate.swift
//  InstantPlayer
//
//  App-owned window lifecycle policy (E2-S2, design §6.1 — S8) and
//  arrow-key delivery (E2-S2 round 4 — S5; coordinator-ratified design
//  §5.3 amendment, D22).
//

import AppKit

/// App-owned policy hooks (D10): close-quits (design §6.1 — S8) and the
/// arrow-key monitor (round 4 — S5). A SwiftUI `Window` scene leaves the
/// app running when its window closes, and no reopen path exists (the
/// in-app picker is a v1 non-goal) — so quitting is the honest
/// single-window behavior. SwiftUI focused-view key delivery
/// (`.onKeyPress`/`.onMoveCommand` with programmatic `@FocusState`)
/// failed three live functional-review rounds — key focus could not be
/// made to land in the scroll content — so arrow keys ship as a ratified
/// App-owned `NSEvent` local key monitor: the pure `ArrowKeyCommand`
/// decision routes each keyDown into the active feed view model's
/// unchanged paging methods; everything else passes through untouched.
/// The delegate also owns the one composition container (D10) — the same
/// container `RootView` binds to. D18's adaptor reservation for *entry
/// routing* stays deliberately unbuilt.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The composition container. Owned here so the monitor and the view
    /// tree share exactly one container (one window, one model — D18);
    /// allocation-only at init (R13): the monitor installs in
    /// `applicationDidFinishLaunching`, never in `init`.
    let dependencies = AppDependencies()

    /// The installed local key monitor's token — held so the monitor has
    /// an owner for the app's lifetime.
    private var keyMonitor: Any?

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Local monitors fire on the main thread; the decision is O(1)
        // pure arithmetic (RNF-02) and the paging call is the existing
        // `@MainActor` view-model method. Auto-repeat while held = repeated
        // presses — one item per keyDown (standard, accepted by the spec).
        // `[weak self]` breaks the token→closure→self cycle.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let command = ArrowKeyCommand.route(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                hasOpenFeed: Self.hasOpenFeed(on: dependencies.activeFeedModel)
            )
            switch command {
            case .pageForward:
                dependencies.activeFeedModel?.pageForward()
                return nil
            case .pageBackward:
                dependencies.activeFeedModel?.pageBackward()
                return nil
            case .passThrough:
                return event
            }
        }
    }

    /// The routing input derived from the state machine (evidence §8): the
    /// feed is "open" only when its state is `.folderOpen` — welcome passes
    /// every key through. Synchronous on the main thread (no awaits between
    /// this read and the paging call), so the decision cannot race the
    /// state machine.
    private static func hasOpenFeed(on model: FeedViewModel?) -> Bool {
        guard let model, case .folderOpen = model.state else { return false }
        return true
    }
}
