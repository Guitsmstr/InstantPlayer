---
name: swift-performance
description: Performance requirements for InstantPlayer — main thread, SwiftUI view cost, playback efficiency, memory, launch; load when building or reviewing anything performance-relevant (RNF-02)
---

# Swift/macOS performance (pillar — RNF-02)

Instant playback is the product promise: the app must feel immediate. Goal: smooth 60/120 fps UI, no main-thread stalls, no avoidable memory growth. Requirements below are review-level; violations are blockers when they touch the playback path.

## 1. Main-thread discipline

- The main thread is for UI only. Disk I/O, parsing, hashing, network, and media processing go to background tasks (`Task.detached`/actors) with results marshaled back.
- No synchronous file reads in `init` of views or `App`. Prefer async loading states over blocking.

## 2. SwiftUI view cost

- `body` must be cheap: no I/O, no heavy computation, no formatting of large datasets inside `body`. Precompute in a model or cache.
- Scope state finely: `@State`/`@Observable` per view, not app-wide god objects; invalidation propagates to everything observing.
- Long lists use `LazyVStack`/`LazyHGrid`/`List` with stable identities; avoid `AnyView` in hot paths (destroys diffing).
- Avoid `onAppear`-driven work that re-runs on every navigation; make idempotent or keyed.

## 3. Playback (core domain)

- Player creation is expensive: create once per screen, reuse, and tear down (`player = nil`, clear items) on disappear — leaking players keep output devices and decoders alive.
- Keep the audio/video session configuration minimal and restore previous state when the app requires it.
- Large files stream/progress-load; never copy a user's multi-GB file to play it.

## 4. Memory

- Thumbnails/artwork: downsample to display size (e.g. `ImageIO` thumbnail), never decode full-resolution media into a grid.
- Closures capturing views/models strongly in long-lived contexts (delegates, timers, player callbacks) → `[weak self]`; Instruments (Leaks/Allocations) on anything suspicious.
- Caches need an eviction policy (NSCache or count/byte-bounded).

## 5. Launch

- Keep `App.init` and `@main` setup minimal; defer non-critical work past first frame. Launch is part of "instant".

## 6. Measurement, not vibes

- Performance claims in stories need measured evidence: XCTest `measure` blocks / metrics for unit-level, Instruments traces for systemic claims. "It feels fast" is not evidence.
- The gate runs build + unit tests; add performance-sensitive unit tests where a regression can be caught deterministically.

## Review checklist

- [ ] No disk/network/decode work on the main thread or inside `body`
- [ ] Lists lazy with stable identities; state scoped to where it is used
- [ ] Players created once, torn down on disappear; large media streamed, not copied
- [ ] Thumbnails downsampled; caches bounded; no obvious retain cycles
- [ ] Launch path minimal; non-critical work deferred
- [ ] Performance-sensitive claims backed by measurement
