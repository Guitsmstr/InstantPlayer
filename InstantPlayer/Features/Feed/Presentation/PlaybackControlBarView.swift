//
//  PlaybackControlBarView.swift
//  InstantPlayer
//
//  Feed Presentation — the overlay control bar (E3-S1, design §4 — S3,
//  S5–S7, S11; D27's ratified surface; E3-S2, design §4 — S1, S3, S4:
//  the speed menu, the ≠1× badge, and the cluster's hit-test island).
//

import SwiftUI

/// The overlay control bar (design §4): a dumb binder over
/// `PlaybackControlBarModel` (D8 — no policy in views) rendering exactly
/// the six named elements — the progress track (a thin line, full
/// width), the scrubber thumb riding on it, the elapsed label (leading),
/// the duration label (trailing), and — since E3-S2 — the trailing speed
/// cluster: the speed menu and the ≠1× badge (the plain amendment of the
/// bar-contents contract, E3-S2 S3; nothing else). Rendered only while
/// the page's bar model is non-`nil`; visibility (opacity/hit-testing)
/// is the caller's overlay semantics (task 7) — this view is the
/// shown-bar surface.
///
/// Gestures report geometry as **fractions** (`0...1` along the track —
/// geometry stays a view concern, design §5): a `DragGesture(
/// minimumDistance: 3)` drives begin/change/end at phase transitions (a
/// pure click never crosses the threshold and stays a tap — so a click
/// cannot pause, S11/S10), and a tap on the track is the track-click
/// seek (S11). The strip's drag is a `highPriorityGesture` so a scrub
/// never starts a paging gesture; the labels, strip padding, and the
/// speed cluster are consumed no-ops — everything on the strip is
/// excluded from the whole-page toggle target (S11's carve-out), and the
/// cluster is its own hit-test island (E3-S2 design §4: its drags never
/// start paging either).
struct PlaybackControlBarView: View {
    /// The bar's value (design §7) — the only state this binder reads.
    let model: PlaybackControlBarModel

    /// The scrub entry points (design §5) and the track click (S11), each
    /// pre-captured with the page's item id at the drill site (task 7).
    let onScrubBegan: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void
    let onTrackClick: (Double) -> Void

    /// The speed-menu selection (E3-S2 design §4): write-through to the
    /// drilled closure — the binder owns no state (D8).
    let onSpeedSelected: (MediaPlaybackSpeed) -> Void

    var body: some View {
        VStack(spacing: 6) {
            TrackSurface(
                fraction: model.scrubFraction,
                onScrubBegan: onScrubBegan,
                onScrubChanged: onScrubChanged,
                onScrubEnded: onScrubEnded,
                onTrackClick: onTrackClick
            )
            .frame(height: 14)
            HStack {
                Text(mmss(model.elapsed))
                Spacer()
                SpeedCluster(speed: model.speed, onSpeedSelected: onSpeedSelected)
                Text(mmss(model.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        // Consumed no-op (S11's carve-out): the labels and strip padding
        // are part of the strip, so their hits are excluded from the
        // whole-page toggle target — a click there does nothing at all
        // (the spec seeks only on the track). Badge taps land here too
        // (E3-S2 design §4: a badge is not a control).
        .onTapGesture {}
    }

    /// The `mm:ss` formatter (design §4): tiny and pure, evaluated only
    /// here in the bar's two label views (skill §2 — no formatting churn
    /// beyond two labels at 10 Hz while visible).
    private func mmss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// The speed display strings (E3-S2 design §4) — the exact five
    /// presets, pinned unit-testably (the `mmss` precedent): `0.25×`,
    /// `0.5×`, `1×`, `1.5×`, `2×`. The badge and the menu rows render
    /// from this one formatter alone.
    nonisolated static func speedText(_ speed: MediaPlaybackSpeed) -> String {
        switch speed {
        case .quarter:
            "0.25×"
        case .half:
            "0.5×"
        case .normal:
            "1×"
        case .oneAndHalf:
            "1.5×"
        case .double:
            "2×"
        }
    }
}

/// The trailing speed cluster (E3-S2 design §4): the ≠1× badge and the
/// speed menu — one hit-test island inside the strip. The island's own
/// `contentShape` + consumed drag mean speed-surface interactions never
/// toggle playback (the strip's carve-out — a click on the menu is
/// claimed by the `Menu` itself, a badge tap falls to the strip's
/// consumed no-op), never start a scrub (the track gesture is the
/// track's own), and never start paging (the consumed drag beats the
/// scroll surface — the same `highPriorityGesture` reasoning the strip
/// uses for scrubs).
private struct SpeedCluster: View {
    /// The selected speed (from the model alone — the checkmark and the
    /// badge render from this value; D8: the binder owns no state).
    let speed: MediaPlaybackSpeed
    let onSpeedSelected: (MediaPlaybackSpeed) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if speed != .normal {
                // The speed badge (S4): iff the selection differs from 1× —
                // nothing at 1× (US5's chrome minimality), the identity at
                // every other preset. Monospaced so the strip does not
                // twitch as digits change.
                Text(PlaybackControlBarView.speedText(speed))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
            Menu {
                // The native mutually-exclusive menu with a checkmark on
                // the selected preset (S1). Write-through binding: the
                // setter forwards to the drilled closure — the binder owns
                // no state (D8).
                Picker(
                    "Speed",
                    selection: Binding(
                        get: { speed },
                        set: { onSpeedSelected($0) }
                    )
                ) {
                    ForEach(MediaPlaybackSpeed.allCases, id: \.self) { preset in
                        Text(PlaybackControlBarView.speedText(preset))
                            .tag(preset)
                    }
                }
                .pickerStyle(.menu)
            } label: {
                // Constant copy (design §4): at 1× the closed control shows
                // no number — the state is visible in the badge when ≠ 1×
                // and in the menu's checkmark when open.
                Label("Speed", systemImage: "speedometer")
            }
        }
        .contentShape(Rectangle())
        // The consumed drag island (design §4): a drag starting anywhere on
        // the cluster is consumed — never a scrub, never a paging gesture.
        .highPriorityGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in }
                .onEnded { _ in }
        )
    }
}

/// The track and its thumb — one gesture surface (design §4): the thin
/// full-width line, the thumb riding at the model's fraction, and the
/// tap/drag pair that reports fractions to the view model's entry points.
private struct TrackSurface: View {
    let fraction: Double
    let onScrubBegan: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void
    let onTrackClick: (Double) -> Void

    /// True from the drag's first movement until its end — the phase
    /// transition that fires `onScrubBegan` exactly once (a pure click
    /// never reaches it, S11/S10).
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.35))
                    .frame(maxWidth: .infinity, minHeight: 3, maxHeight: 3)
                Circle()
                    .fill(.primary)
                    .frame(width: 11, height: 11)
                    .offset(x: max(0, min(width - 11, fraction * width - 5.5)))
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                onTrackClick(Self.fraction(ofX: location.x, width: width))
            }
            .highPriorityGesture(
                // The strip owns its drags (design §4): a scrub never
                // starts a paging gesture, and the drag tracks past the
                // strip's bounds once started (standard SwiftUI drag
                // semantics). Begin/change/end fire at the gesture's
                // phase transitions; the drag's local space is the track.
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onScrubBegan()
                        }
                        onScrubChanged(Self.fraction(ofX: value.location.x, width: width))
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false
                        onScrubEnded(Self.fraction(ofX: value.location.x, width: width))
                    }
            )
        }
    }

    /// The fraction for an x coordinate along the track (design §5):
    /// `clamp(x / width, 0, 1)` — no unbounded geometry ever leaves the
    /// view.
    private static func fraction(ofX locationX: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return min(max(locationX / width, 0), 1)
    }
}
