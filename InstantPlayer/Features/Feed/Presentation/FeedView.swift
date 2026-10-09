//
//  FeedView.swift
//  InstantPlayer
//
//  Feed Presentation view — a dumb binder (E1-S3, design §3.8 — R3).
//

import SwiftUI

/// Views are dumb binders: no state of their own, no Data imports (R2),
/// no direct framework access (R11). Not hosted by `RootView` in the
/// skeleton (R13); it is the template future feature views copy.
struct FeedView: View {
    let viewModel: FeedViewModel

    var body: some View {
        Text(viewModel.probeResult ?? "Feed shell — wiring only, no product behavior yet")
            .padding()
            .task { await viewModel.runWiringProbe() }
    }
}
