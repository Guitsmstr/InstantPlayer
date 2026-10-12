# E2-S2 · Vertical feed & window — Story Spec

## Story context

- **Why this story, why now.** Walking-skeleton leg 2. E2-S1 made the app able to **open a folder and know its media**; until now the folder-open state shows only an interim placeholder. After this story the app can **show that media and flip through it** — one vertical feed, each item filling the window, scroll/arrow paging, single-window behavior complete. Nothing plays yet: playback is E2-S3, and this spec claims none of it.
- **What "vertical feed & window" means end to end.** The folder-open state presents the collected media as one vertical feed of videos and images (product R7), the current item filling the viewport letterboxed (product R8) — a video item shows its first frame as a static poster, honestly carrying product R8 until playback exists. Paging is feed-style magnetic snap: one scroll gesture or one arrow press moves exactly one item (product R9, R10), stopping at both ends. The single resizable window (product R37) is the one surface: a new open replaces the previous collection in place (product R38), resize and native fullscreen keep the current item filling the view (product R39, R40), and closing the window quits the app.
- **Product requirements carried.** product R7–R10 (feed navigation) and product R37–R40 (window) from [docs/spec.md](../../spec.md) — referenced below as `product R#`, never renumbered or restated as new normative text. Product R16 (cross-cutting responsiveness) applies as this story's share via S15, per the coverage note in [docs/backlog.md](../../backlog.md). Story-scoped requirements (derivations and refinements) are numbered **S1…S16** in this file only.
- **Pillars.** Both pillars are engaged. **RNF-02 (performance):** feed rendering, paging responsiveness, and poster/first-frame work all touch images and SwiftUI views — the perceptual promise here is that paging never stalls (product R16) and items appear without perceptible lag; numeric budgets are this story's design-phase output, which loads the `swift-performance` skill per the pillar rule (D5). **RNF-04 (security):** the feed reads media only through the already-open security-scoped session of E2-S1 (D19) — no new access paths, no persistence, and file names remain display-only (D20); the design loads the `swift-security` skill.
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE affected.** This story replaces the launch-visible interim folder-open placeholder with the feed and changes visible UI throughout — exactly what the `InstantPlayerUITests` launch surface covers. The validator/converge step therefore runs `./scripts/validate.sh --uitests` for this story ([docs/development.md](../../development.md) §3). Caveat recorded honestly, same as E2-S1's: entry flows remain host-driven (Open With and drag & drop cannot be driven by UI tests), and the feed presentation itself — letterboxing, video posters, paging snap, unavailable states — is verified by stakeholder functional review; unit tests carry the paging state machine (S4–S6).
- **Inherited contracts (E2-S1).** `FeedState.folderOpen(MediaCollection)` with its `startIndex` starting-item contract (the feed starts there); the interim folder-open placeholder, which this story replaces outright; the single `Window` scene (D18 — one window, one state machine); the snapshot staleness contract (E2-S1 design §6 — the collection may drift from disk after open; S12–S13 are the display-time fail-safe for that drift); the open security-scoped session (D19); and the honest declared-type classification contract (D20 — a mislabeled file is collected as its declared kind and fails at consumption time, which is S13 here).
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md) (Feed feature: `FeedState`/`FeedViewModel`/`FeedView`). Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a Mac user reviewing a folder of clips and images, I want them all in one vertical feed where the current item fills the window, so that viewing is immersive and undistracted — a clean viewport, no chrome.
- **US2** · As a user flipping through media, I want one scroll gesture or one arrow press to move exactly one item and always rest on a full item, so that paging is predictable — and it stops politely at the first and last item.
- **US3** · As a user looking at a video before playback exists, I want to see its first frame as a still poster, so that videos are honestly represented in the feed from day one.
- **US4** · As a user who often opens new media mid-session, I want the same window to take over with the new collection positioned where I entered it — and closing the window to quit the app — so that the app behaves like one focused viewer, not a document manager.
- **US5** · As a user with a folder that changed since I opened it, I want a vanished or unreadable item to show a plain unavailable state instead of breaking, so that I can keep flipping through the rest of the feed.

## Story requirements (EARS)

Numbering is story-local: **S1…S16** for this story only. Product requirements are cited as `product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that merely anchor product text cite it; requirements that refine or derive add a short derivation note.

### Feed presentation (product R7, R8)

- **S1:** WHEN a folder's media collection is presented in the folder-open state
  THE SYSTEM SHALL show its videos and images together in one vertical feed (product R7), in the collection's snapshot order

*Derivation (S1):* "one vertical feed" means both kinds share a single paging sequence — there is no separate images strip or videos strip. The order is the collection's snapshot order (the folder's own order at open time, E2-S1 S14); ordering modes are E4-S1 (product R21–R22) and the feed applies none of its own. This contract replaces the interim folder-open placeholder outright.

- **S2:** WHEN an item is the current item in the feed
  THE SYSTEM SHALL display it filling the viewport, preserving its aspect ratio (letterboxing as needed) (product R8)

- **S3:** WHEN a video item is displayed in the feed
  THE SYSTEM SHALL display its first frame as a static poster — a still image, letterboxed per product R8 (product R8, carried for videos by the poster in this story)

*Derivation (S3):* playback and auto-play are E2-S3 (product R11) and are not claimed here; until they exist, a video's visible representation in the feed is its first frame as a still poster — no motion, no transport. How the first frame is obtained is design detail; this spec states the visible contract. If the poster cannot be produced (S13), the unavailable state applies instead.

### Feed paging (product R9, R10)

- **S4:** WHEN the user performs a scroll gesture on the feed
  THE SYSTEM SHALL move exactly one item in the gesture's direction and come to rest showing exactly one full item (product R9)

*Derivation (S4):* feed-style magnetic snap — one gesture = one page. There is no momentum multi-page travel: any scroll gesture moves exactly one item regardless of gesture size or speed, and the resting state is always a full item (never two half items).

- **S5:** WHEN the user presses the ↓ or ↑ arrow key while the feed is presented
  THE SYSTEM SHALL advance to the next item or return to the previous item (product R10)

- **S6:** WHEN paging reaches the first or the last item of the collection
  THE SYSTEM SHALL stop there — paging SHALL NOT wrap around, for scroll gestures (product R9) and arrow keys (product R10, "when one exists") alike

*Derivation (S6):* product R10's "when one exists" bounds paging at the ends; the same bound applies to scroll paging, so both mechanisms clamp at the first and last item in both directions.

### Window (product R37–R40)

- **S7:** WHEN the app is running with media presented
  THE SYSTEM SHALL show the feed in the app's single window, which the user can resize (product R37)

*Note (S7):* product R37 names "the feed and list"; the list arrives in the same window with E5-S1 and is not claimed here. The single-window shell itself (the `Window` scene, one state machine) is inherited from E2-S1 (D18); this story's obligation is the feed behaving correctly inside it.

- **S8:** WHEN the user closes the single window
  THE SYSTEM SHALL quit the application

*Derivation (S8):* refinement of product R37's single-window model — one window, one lifecycle. There is no reopen path after close: the in-app folder picker is a v1 non-goal ([docs/spec.md](../../spec.md)), so close = quit is the honest single-window behavior.

- **S9:** WHEN media is opened while a folder is already being viewed
  THE SYSTEM SHALL present the newly opened collection in that same window, replacing the previous one, positioned at the new collection's starting item (product R38)

*Derivation (S9):* "positioned at the starting item" is inherited from E2-S1's `startIndex` contract — a file entry lands on that file, a folder entry on the collection's first item. Replace-in-place is full: the previous collection, its position, and any display state for it are discarded.

- **S10:** WHEN the user resizes the window
  THE SYSTEM SHALL keep the current item filling the viewport (product R39)

- **S11:** WHEN the user enters or leaves native macOS fullscreen (green button or ⌃⌘F)
  THE SYSTEM SHALL keep displaying the current item filling the screen (product R40)

*Note (S11):* fullscreen is the system's native mode, not an app-defined one; the current item fills the screen under the same aspect-preserving letterbox rule as product R8 (S2).

### Fail-safe display of stale items (derivation; E2-S1 design §6, D20)

- **S12:** WHEN the file behind the current item or another displayed item has vanished or become unreadable since the collection snapshot was taken
  THE SYSTEM SHALL display a neutral unavailable state for that item and SHALL keep the feed navigable — paging to adjacent items continues to work

*Derivation (S12):* the collection is a point-in-time snapshot that may drift from disk (E2-S1 S13, design §6); live removal handling is E4-S2 (product R24, R26) and is not claimed here. Until it exists, stale items fail safe at display time: an unavailable state, never a broken or stalled feed. The unavailable state is deliberately neutral — no file name overlay (S14) and no implied retry semantics.

- **S13:** WHEN a video item's first frame cannot be produced — for example a mislabeled file collected under its declared type (D20's honest declared-type contract: a `fake.mp4` holding non-video bytes)
  THE SYSTEM SHALL display the same neutral unavailable state in place of the poster (S12) and SHALL keep the feed navigable

*Derivation (S13):* D20 pins that content bytes are not sniffed at collection time, so mislabeled files arrive in the feed and fail at consumption. This story's consumption is the poster; S13 is that failure's display contract. The playback-side failure handling of the same contract is E2-S3's.

### Viewport cleanliness and responsiveness (decision 3; product R16)

- **S14:** WHEN an item is displayed in the feed
  THE SYSTEM SHALL present it in a clean, chrome-free viewport — no file-name overlay, no position counter, no scrollbar

*Derivation (S14):* settled interview decision 3: the v1 feed viewport is full-bleed and carries no chrome. File names surface in E5-S1's list; playback controls arrive with E3. The item itself remains letterboxed per product R8 (S2).

- **S15:** WHEN the user pages through the feed, resizes the window, or enters or leaves fullscreen
  THE SYSTEM SHALL keep the interface smooth and responsive, with no stalls (product R16, RNF-02)

*Note (S15):* product R16 is deliberately not assigned to any single story ([docs/backlog.md](../../backlog.md) coverage note) — S15 states this story's share of the responsiveness budget. Numeric budgets are set in this story's design (RNF-02), which loads the `swift-performance` skill.

### Welcome interplay (inherited, E2-S1 S5–S7)

- **S16:** WHEN the app is presenting the welcome state
  THE SYSTEM SHALL present no feed and no feed paging — feed and paging apply only in the folder-open state, and the welcome state's behavior is unchanged

*Derivation (S16):* paging and feed navigation presuppose an open collection; E2-S1's welcome-state contract (S5–S7) stands untouched, including its drop-target behavior and its transitions on entry actions.

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in [docs/spec.md](../../spec.md) apply unchanged):

- **Playback, auto-play, loop** (E2-S3) — product R11, R12, R15, R17. Video items show a static first-frame poster only (S3); no motion, no transport, no audio.
- **Scrub & playback speed** (E3-S1 / E3-S2) — product R13, R14. **Volume & mute** (E3-S3) — product R18–R20.
- **Feed chrome** (this story's settled decision 3) — no file-name overlay, position counter, or scrollbar here (S14); playback controls come with E3, file names with E5-S1's list. Adding chrome is future work, not deferred work in this story.
- **Image zoom/pan** (this story's settled decision 4) — images are fit-to-viewport and letterboxed like videos (product R8, S2); magnification and panning are future work for a later story.
- **Wrap-around paging** (settled: none) — paging clamps at the first and last item (S6); looping the feed is not a v1 behavior.
- **Ordering modes** (E4-S1) — product R21–R22; the feed order is the collection's snapshot order (S1) and is not switchable.
- **Live folder sync** (E4-S2) — product R23–R26; snapshot staleness is handled by the display-time fail-safe (S12–S13), not by tracking the folder.
- **List view & file operations** (E5-S1 / E5-S2) — product R27–R33; the window is feed-only in this story (S7's note).
- **In-app folder picker / reopen path** — v1 non-goal ([docs/spec.md](../../spec.md)); it directly shapes S8: with no reopen path, closing the window quits.
- **Network** — excluded from v1 entirely (D9); this story reads local files only.

## Acceptance criteria

Product-requirement coverage map — each product requirement assigned to this story (the eight of [docs/backlog.md](../../backlog.md): R7–R10, R37–R40) maps to a verifiable story outcome; product R16 is carried as a cross-cutting share via S15 and is not claimed as this story's own:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R7 (one vertical feed) | S1 — videos and images in one paging sequence, snapshot order | functional review (mixed folder) + unit tests on the feed state |
| R8 (current item fills viewport) | S2, S3 — letterboxed fit for images; video poster carries R8 until playback (E2-S3) | functional review (image and video items, letterboxing) |
| R9 (scroll paging) | S4 — one gesture = one page, magnetic snap, always a full item | unit tests on the paging state + functional review (snap, no momentum multi-page) |
| R10 (arrow keys) | S5, bounded by S6 — ↓/↑ move one item, clamp at both ends | unit tests (clamping) + functional review |
| R37 (single resizable window) | S7, S8 — feed in the one resizable window; close quits | functional review (resize, close) |
| R38 (replace in place) | S9 — same window takes the new collection at its starting item | functional review (open while viewing) + unit tests (folderOpen positioned at `startIndex`) |
| R39 (resize) | S10 — current item keeps filling the viewport | functional review |
| R40 (fullscreen) | S11 — native fullscreen in and out, current item fills the screen | functional review |

- [x] Every product requirement assigned to this story maps to at least one story requirement; no other product requirement is claimed here (product R11–R20, R21–R33 stay with their stories; product R16 appears only as the shared responsiveness note S15).
- [x] Paging semantics are explicit and testable without driving scroll hardware: one page per gesture, no momentum multi-page (S4), clamp without wrap (S6) — unit tests on the paging state machine.
- [x] Fail-safe display is explicit for the snapshot-staleness contract (S12) and for D20's mislabeled-video case (S13), with the feed staying navigable in both.
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run includes `--uitests` (UI-test mandate, R14 of E1-S2 — decision in Story context).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: a mixed video+image feed with letterboxing; a video shown as a static first-frame poster; scroll paging with magnetic snap (one item per gesture); arrow-key paging; paging stopping at the first and last item; resize keeping the current item filled; native fullscreen in and out; a new open replacing the collection in place at its starting item; window close quitting the app; and the unavailable state for a vanished file and a mislabeled video (this is a UI story — functional review is part of the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R7–R10, R37–R40; R16; RNF-02 / RNF-04; non-goals)
- [docs/decisions.md](../../decisions.md) — D7 (layering & seams), D8 (presentation & concurrency), D18 (one entry action/one window), D19 (scoped access), D20 (classification), D21 (pbxproj policy)
- [docs/specs/e2-s1-entry-media-collection/spec.md](../e2-s1-entry-media-collection/spec.md) — inherited contracts (`startIndex`, welcome state S5–S7, snapshot semantics S13)
- [docs/specs/e2-s1-entry-media-collection/design.md](../e2-s1-entry-media-collection/design.md) — §3.4 (`Window` scene), §4 (feed-state model, interim placeholder), §6 (snapshot/staleness contract)
- [docs/architecture.md](../../architecture.md) — Feed feature layout (`FeedState`/`FeedViewModel`/`FeedView`)
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E2-S2) and the E2–E5 coverage note
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
