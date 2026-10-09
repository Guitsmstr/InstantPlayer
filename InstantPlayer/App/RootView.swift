//
//  RootView.swift
//  InstantPlayer
//
//  App-owned placeholder root view (E1-S3, design §3.3 — R9, R13).
//

import SwiftUI

/// App-owned placeholder: the future host point for feature views.
/// Receives the container so feature stories swap content here without
/// touching the app entry. Displays static text only — no async, no
/// feature views, no launch work (R13).
struct RootView: View {
    /// Wiring guarantee (scene → container → root) that later stories plug
    /// into; intentionally unused by the placeholder body.
    let dependencies: AppDependencies

    var body: some View {
        VStack {
            Text("InstantPlayer")
            Text("Architecture skeleton — features land in E2 stories")
                .font(.footnote)
        }
        .padding()
    }
}
