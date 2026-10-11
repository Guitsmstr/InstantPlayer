//
//  WelcomeView.swift
//  InstantPlayer
//
//  Feed Presentation — drop-target welcome surface (E2-S1, design §4 — S5).
//

import SwiftUI

/// The drop-target welcome state (S5, product R5): static English copy
/// (D6) and a hover affordance driven by the window drop's `isTargeted`
/// (design §3.1). Static UI — rendered synchronously, zero launch work,
/// no I/O in `body` (design §7.3, RNF-02). The accessibility identifier is
/// the launch assertion's key (§9.4).
struct WelcomeView: View {
    /// True while a window drop hovers over the root (design §3.1).
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            Text("Drop videos or images here")
                .font(.title2.weight(.medium))
            Text("or open a file with InstantPlayer from Finder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
                .padding(8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome-drop-target")
    }
}
