//
//  FeedView.swift
//  InstantPlayer
//
//  Feed Presentation view — a dumb binder (E1-S3, design §3.8 — R3;
//  E2-S1, design §4 — S5–S7).
//

import SwiftUI

/// Dumb binder: renders `WelcomeView` for `.welcome` (S5) and an interim
/// folder-open placeholder for `.folderOpen` — item count + starting-item
/// name. The placeholder is deliberately NOT a feed; E2-S2 replaces it.
/// No state of its own, no Data imports (R2), no direct framework access
/// (R11), no I/O in `body` (RNF-02).
struct FeedView: View {
    let viewModel: FeedViewModel

    /// Window-drop hover state owned by `RootView` (design §3.1); drives
    /// the welcome surface's hover affordance.
    var isDropTargeted: Bool = false

    var body: some View {
        switch viewModel.state {
        case .welcome:
            WelcomeView(isTargeted: isDropTargeted)
        case let .folderOpen(collection):
            VStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                Text(
                    collection.items.count == 1
                        ? "1 media item"
                        : "\(collection.items.count) media items"
                )
                .font(.title3.weight(.medium))
                Text("Starting at \(collection.items[collection.startIndex].name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("The feed arrives in E2-S2")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
