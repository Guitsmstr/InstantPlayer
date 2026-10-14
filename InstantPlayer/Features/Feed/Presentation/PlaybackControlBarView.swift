//
//  PlaybackControlBarView.swift
//  InstantPlayer
//
//  Feed Presentation — the overlay control bar (E3-S1, design §4 — S3,
//  S5–S7, S11; D27's ratified surface).
//

import SwiftUI

/// The overlay control bar (design §4): a dumb binder over
/// `PlaybackControlBarModel` (D8 — no policy in views) rendering exactly
/// the four named elements — the progress track (a thin line, full
/// width), the scrubber thumb riding on it, the elapsed label (leading),
/// and the duration label (trailing); the spec's non-goals exclude
/// everything else. Rendered only while the page's bar model is
/// non-`nil`; visibility (opacity/hit-testing) is the caller's overlay
/// semantics (task 7) — this view is the shown-bar surface.
///
/// Gestures report geometry as **fractions** (`0...1` along the track —
/// geometry stays a view concern, design §5): a `DragGesture(
/// minimumDistance: 3)` drives begin/change/end at phase transitions (a
/// pure click never crosses the threshold and stays a tap — so a click
/// cannot pause, S11/S10), and a tap on the track is the track-click
/// seek (S11). The strip's drag is a `highPriorityGesture` so a scrub
/// never starts a paging gesture; the labels and strip padding are
/// consumed no-ops — everything on the strip is excluded from the
/// whole-page toggle target (S11's carve-out).
struct PlaybackControlBarView: View {
    /// The bar's value (design §7) — the only state this binder reads.
    let model: PlaybackControlBarModel

    /// The scrub entry points (design §5) and the track click (S11), each
    /// pre-captured with the page's item id at the drill site (task 7).
    let onScrubBegan: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void
    let onTrackClick: (Double) -> Void

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
        // (the spec seeks only on the track).
        .onTapGesture {}
    }

    /// The `mm:ss` formatter (design §4): tiny and pure, evaluated only
    /// here in the bar's two label views (skill §2 — no formatting churn
    /// beyond two labels at 10 Hz while visible).
    private func mmss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
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
