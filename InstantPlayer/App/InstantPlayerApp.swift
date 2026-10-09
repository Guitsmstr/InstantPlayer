//
//  InstantPlayerApp.swift
//  InstantPlayer
//
//  App entry + window/scene wiring (E1-S3, design §3.2 — R9, R13).
//

import SwiftUI

@main
struct InstantPlayerApp: App {
    /// Container created once per app instance; zero work beyond
    /// allocation-only construction (design §6).
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
