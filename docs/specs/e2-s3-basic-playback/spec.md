# E2-S3 · Basic playback — Story Spec

## Story context

- **Why this story, why now.** Walking-skeleton leg 3 — the last E2 story. E2-S1 made the app able to open a folder and know its media; E2-S2 made it show that media and flip through it, with videos frozen as static first-frame posters. After this story the walking skeleton is complete: open a folder, see the feed, **and it plays** — auto-play with no perceptible wait, play/pause, loop in place, and the user's files untouched throughout. Everything else about playback (scrub, speed, volume, controls) is E3; this spec claims none of it.
- **What "basic playback" means end to end.** Whenever a video becomes the current item in the feed — which, when paging, means once the paging gesture **settles** on it (S2), never mid-scroll — it starts playing by itself immediately (product R11), with its audio unmuted (settled interview answer 3). The user can pause and resume it with the **spacebar** or a **single click anywhere on the current feed page** (product R12 — settled interview answer 1); a pause shows nothing but the frozen frame. Paging away stops the video; paging back **restarts it from the beginning** (settled interview answer 2). At its end the same video restarts from its beginning — never auto-advance (product R15). Playback is read-only: the user's media files are never rewritten, re-encoded, or modified (product R17).
- **Product requirements carried.** product R11, R12, R15, R17 (playback) from [docs/spec.md](../../spec.md) — referenced below as `product R#`, never renumbered or restated as new normative text. Product R16 (cross-cutting responsiveness) applies as this story's share via S16, per the coverage note in [docs/backlog.md](../../backlog.md). Story-scoped requirements (derivations and refinements) are numbered **S1…S16** in this file only.
- **Pillars.** Both pillars are engaged. **RNF-02 (performance):** "no perceptible wait" before a clip plays is *the* product promise this story exists to deliver (product R11, D13) — auto-play start latency is this story's headline budget, measured from the settle (S2), and it also consumes the shared responsiveness budget through S16; numeric budgets are this story's design-phase output, which loads the `swift-performance` skill per the pillar rule (D5). **RNF-04 (security):** playback reads media **read-only** through the already-open security-scoped session of E2-S1 (D19) — no new access paths, no writes, no sidecar files, no persistence of playback state (S12, S13 — product R17 is a first-class requirement of this story); the design loads the `swift-security` skill.
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE affected.** Plain launch still shows the welcome state, and playback remains unreachable without host-driven entry (Open With and drag & drop) — but once media is open, the launch-visible behavior of the app changes for good: the current item now moves and sounds instead of sitting as a poster. The validator/converge step therefore runs `./scripts/validate.sh --uitests` for this story ([docs/development.md](../../development.md) §3). Caveat recorded honestly, same form as E2-S1's and E2-S2's: entry flows remain host-driven (UI tests cannot drive Open With or drag & drop), so the actual playback behavior — auto-play start on settle, spacebar/click toggle, the click guard, loop at end, restart on revisit, and the unavailable fallback — is verified by stakeholder functional review plus unit tests through the playback seam; the launch tests keep asserting the welcome state and keep guarding launch cost.
- **Inherited contracts (E2-S1, E2-S2).** `FeedState.folderOpen(MediaCollection)` with its `startIndex` starting-item contract (a file entry lands on that file — the video there auto-plays per S1); the feed paging and current-item semantics of E2-S2 S1, S2, S4–S6 (this story adds playback *under* the current item and changes no navigation semantics); the poster pipeline and per-item display states of E2-S2's design §7, which this story extends with a player representation for the current item while neighbors keep their posters (E2-S2 design §4.1, §13); the neutral unavailable state of E2-S2 S12–S13, which this story extends to playback failure (S14, S15 — D20's honest declared-type contract); the chrome-free viewport of E2-S2 S14 (carried by S8); the snapshot staleness contract (E2-S1 design §6); the open security-scoped session (D19 — "E2-S3 must not re-scan the folder or re-derive the session", E2-S2 design §13); and the honest declared-type classification contract (D20). Note for design: E2-S2 shipped the arrow keys as an App-owned input path (D22's consequence) — the spacebar of S5 may route through the same path; input delivery is design detail and this spec states only the visible contract.
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md) (Feed feature), growing the playback seam that E2-S2 deliberately left untouched. Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a Mac user flipping through a folder of clips, I want the video to just play the moment it comes into view — with sound, without waiting — so that reviewing footage feels instant.
- **US2** · As a user inspecting a clip, I want to pause and resume it with the spacebar or one click anywhere on the picture, so that I can hold on a frame without hunting for a tiny control.
- **US3** · As a user studying a short clip, I want it to loop in place when it ends, so that I can keep watching the same clip without touching anything — and without being yanked to the next one.
- **US4** · As a user flipping back to a clip I already saw, I want it to start fresh from the beginning, so that playback is predictable and the app stays light.
- **US5** · As a user reviewing camera dumps and downloads, I want my original files never touched — read, never written — so that I can trust the app with my media.
- **US6** · As a user whose folder contains a broken or vanished clip, I want a plain unavailable state instead of a broken player, so that I can keep flipping through the rest of the feed.

## Story requirements (EARS)

Numbering is story-local: **S1…S16** for this story only. Product requirements are cited as `product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that merely anchor product text cite it; requirements that refine or derive add a short derivation note.

### Auto-play (product R11)

- **S1:** WHEN a video becomes the current item in the feed
  THE SYSTEM SHALL start playing it automatically, with no perceptible wait on the happy path (product R11)

*Derivation (S1):* "becomes the current item" covers **every** path onto a video — the starting item at folder open (the inherited `startIndex` contract), paging forward onto a video, paging back to one (S10 restarts it — the auto-play here is a fresh start), and the starting item of a replace-in-place open (E2-S2 S9). When the path is paging, the trigger point is the settle, not the gesture (S2). Images are excluded (S4). The "no perceptible wait" budget is RNF-02's headline promise for this story and gets its numeric bound in design (D13: playback start is the app's headline performance budget); on paging it is measured from the settle — the moment the item becomes current (S2).

- **S2:** WHEN the user is paging to another feed item (scroll gesture or arrow key) and the paging has not yet settled on the incoming item
  THE SYSTEM SHALL keep the incoming item displayed as its static poster and SHALL NOT start its playback — auto-play (S1) fires only when the paging settles on the item (the one-gesture-one-page rest of E2-S2 S4)

*Derivation (S2):* coordinator-settled clarification of product R11's "becomes the current item": auto-play triggers on paging **settle**, not mid-gesture. The destination is undetermined until settle — playing a video being scrolled past would blip its audio and immediately stop it; "becomes the current item" presupposes the current item, which exists only at rest (the same "settled current item" premise the click guard S7 uses). The no-perceptible-wait budget (RNF-02) is measured from the moment the item becomes current — the settle — since that is the user-perceived start moment.

- **S3:** WHEN auto-play starts a video
  THE SYSTEM SHALL play it with its audio unmuted

*Derivation (S3):* settled interview answer 3 — the instant-viewing promise includes sound; videos are not muted by default. App-level volume and mute are E3-S3 (product R18–R20) and are not claimed here; until they exist, the hardware/system output volume is the user's control.

- **S4:** WHEN an image is the current item in the feed
  THE SYSTEM SHALL perform no playback action — its display contract is unchanged from the feed display contract (E2-S2 S2, S14)

*Derivation (S4):* images have no playback semantics; auto-play (S1), play/pause (S5–S6), and loop (S11) apply to videos only. Clicking an image's current page is a no-op (S7).

### Play/pause (product R12 — settled interview answer 1)

- **S5:** WHEN the current item is a video and the user presses the spacebar
  THE SYSTEM SHALL toggle its playback — pause it when playing, resume it when paused (product R12)

*Note (S5):* product R12 says "invokes play or pause"; the spacebar is the settled keyboard invocation. Input delivery is design detail (see Story context: the App-owned input path of D22's consequence). With an image as the current item, the spacebar has no play/pause to invoke (product R12's "current item is a video" condition) and is a no-op.

- **S6:** WHEN the current item is a video and the user clicks once anywhere on the current feed page
  THE SYSTEM SHALL toggle its playback — pause it when playing, resume it when paused (product R12)

*Derivation (S6):* settled interview answer 1 — the **whole current page** is the click target, letterbox area included; there is no smaller hit area and no visible control to aim at.

- **S7:** WHEN the user clicks on a non-current feed page, clicks while a paging gesture is still in flight, or clicks the current page of an image
  THE SYSTEM SHALL treat the click as a no-op

*Derivation (S7):* the toggle is guarded to the **settled current item** — clicks on neighbors and clicks mid-gesture do nothing (settled interview answer 1), and an image page has no playback to toggle (S4). Two recorded consequences of the whole-page click target, both stated as non-goals below: **double-click has no meaning in v1** (native fullscreen entry stays the green button / ⌃⌘F only — E2-S2 S11), and this choice commits E3-S1's scrubbing to a **hover/mouse-move overlay control bar** — drag-on-video scrubbing is foreclosed.

- **S8:** WHEN playback is paused
  THE SYSTEM SHALL indicate the pause only by the frozen frame — no controls overlay, no progress indicator, no play button

*Derivation (S8):* carries E2-S2 S14's chrome-free viewport into playback — the viewport stays chrome-free in both playback states, and the frozen frame is the only pause state this story ships. Transport chrome is E3's decision (non-goal).

### Revisiting a video (settled interview answer 2 — current-item semantics)

- **S9:** WHEN the user pages away from the current video
  THE SYSTEM SHALL stop its playback

*Derivation (S9):* settled interview answer 2 — paging away (scroll gesture or arrow key, E2-S2 S4–S5) stops the video; nothing keeps playing off-screen. The departed item's playback state is discarded (S10).

- **S10:** WHEN the user pages back to a video that was played earlier in this open session
  THE SYSTEM SHALL restart it from its beginning (auto-play per S1 applies as a fresh start)

*Derivation (S10):* settled interview answer 2 — deterministic and memory-light: there is **no resume** and nothing carries across visits (no remembered position, no kept-alive playback state). Resume positions are a non-goal below.

### Loop in place (product R15)

- **S11:** WHEN the current video reaches its end
  THE SYSTEM SHALL restart the same video from its beginning and SHALL NOT automatically advance to the next feed item (product R15)

*Derivation (S11):* product R15 made explicit as a story requirement — loop in place; how the restart is achieved is design detail. Feed advancement stays always user-driven (E2-S2's paging); auto-advance is foreclosed (non-goal).

### Read-only playback (product R17 — first-class in this story)

- **S12:** WHEN playback is exercised on any media file
  THE SYSTEM SHALL never rewrite, re-encode, or otherwise modify that file's contents (product R17)

*Derivation (S12):* product R17 is a headline requirement of this story, not an inherited afterthought: playback is a read of the user's file and nothing else. The v1 non-goal "file editing/export" ([docs/spec.md](../../spec.md)) is hereby concretized for the playback surface.

- **S13:** WHEN playback reads a media file
  THE SYSTEM SHALL read it only through the already-open session of the current collection and SHALL write nothing to disk — no re-encoded copies, no sidecar files, and no persisted playback state

*Derivation (S13):* S12's story-level consequences made explicit (settled): nothing is written anywhere around playback — no derived copies, no sidecars (no chapters/thumbnails/previews on disk), and playback state (position, pause state) has no disk persistence in v1 (none exists at all — which also forecloses resume across launches, a non-goal below). Access posture is inherited, not re-derived: the security-scoped session of D19 is already open (E2-S2 design §13: E2-S3 must not re-scan the folder or re-derive the session).

### Playback failure (extends E2-S2 S13; D20)

- **S14:** WHEN the current video cannot produce frames at playback time — for example a mislabeled file collected under its declared type (D20's honest declared-type contract: a `fake.mp4` holding non-video bytes)
  THE SYSTEM SHALL fall back to the existing neutral unavailable state (E2-S2 S13's contract extended to playback failure) and SHALL keep the feed navigable

*Derivation (S14):* D20 pins that content bytes are not sniffed at collection time, so mislabeled files arrive in the feed and fail at consumption. E2-S2 S13 covered poster-time failure; this story extends the **same** contract — same neutral state, same no-retry semantics, same navigable feed — to playback-time failure (the explicit E2-S2 design §13 handoff).

- **S15:** WHEN the file behind the current video has vanished or become unreadable since the collection snapshot was taken
  THE SYSTEM SHALL show the same neutral unavailable state (E2-S2 S12) and SHALL keep the feed navigable

*Derivation (S15):* stale items inherit E2-S2 S12's fail-safe unchanged — display-time only, sticky for the session, no folder re-scan (E2-S1 design §6's snapshot contract). Live removal semantics are E4-S2 (product R24, R26) and are not claimed here.

### Responsiveness (product R16)

- **S16:** WHEN the user starts, pauses, resumes, or loops playback, or pages between items during playback
  THE SYSTEM SHALL keep the interface smooth and responsive, with no stalls (product R16, RNF-02)

*Note (S16):* product R16 is deliberately not assigned to any single story ([docs/backlog.md](../../backlog.md) coverage note) — S16 states this story's share of the responsiveness budget. Numeric budgets are set in this story's design (RNF-02), which loads the `swift-performance` skill.

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in [docs/spec.md](../../spec.md) apply unchanged):

- **Scrub & seek** (E3-S1) — product R13. This story ships **no timeline UI and no seek behavior of any kind**. Recorded consequence of the whole-page click target (S6–S7): E3-S1's scrubbing must live in a **hover/mouse-move overlay control bar** — drag-on-video scrubbing is foreclosed by this story's input decision.
- **Double-click** — no meaning in v1 (settled interview answer 1's recorded consequence). Native fullscreen entry remains the green button / ⌃⌘F only (E2-S2 S11); fullscreen behavior itself is unchanged.
- **Playback speed** (E3-S2) — product R14.
- **Volume & mute** (E3-S3) — product R18–R20. Until they exist, videos play unmuted (S3) and the hardware/system output volume is the user's control.
- **Transport chrome — controls, progress indicator, play button** (E3 decides) — the frozen frame is the only pause state (S8); the viewport stays chrome-free per E2-S2 S14. Adding chrome is future work, not deferred work in this story.
- **Auto-advance** — foreclosed by product R15 (S11): at end the same video restarts; feed advancement is always user-driven.
- **Resume positions** — across paging (settled interview answer 2, S10) or across launches (no playback-state persistence exists in v1, S13). Deterministic restarts are the v1 semantics.
- **Images and playback** — no playback semantics for images (S4); their display contract is unchanged from E2-S2.
- **Live folder sync / richer staleness handling** (E4-S2) — product R23–R26; stale items get the inherited unavailable state (S15), not live tracking.
- **Feed navigation & window behavior** — unchanged from E2-S2 (its S4–S11); this story puts playback under the current item and alters no paging, ordering, or window semantics.
- **Network** — excluded from v1 entirely (D9); playback reads local files only.

## Acceptance criteria

Product-requirement coverage map — each product requirement assigned to this story (the four of [docs/backlog.md](../../backlog.md): R11, R12, R15, R17) maps to a verifiable story outcome; product R16 is carried as a cross-cutting share via S16 and is not claimed as this story's own:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R11 (auto-play, no perceptible wait) | S1–S3 — auto-play with audio unmuted on every become-current path (open, paging settle, revisit, replace-in-place) | unit tests through the playback seam (auto-play trigger set, incl. settle-only start) + functional review (start felt instant on the happy path) |
| R12 (play/pause) | S5 (spacebar), S6 (single click on the whole current page), guarded by S7; frozen-frame pause state S8 | unit tests (toggle state + click guard) + functional review (both inputs, guard cases) |
| R15 (loop in place, never auto-advance) | S11 — end restarts the same video from its beginning | unit tests (end-of-media → restart, no advance) + functional review (watch a clip hit its end) |
| R17 (media files never rewritten) | S12, S13 — read-only playback inside the open session; nothing written to disk, no playback-state persistence | validator security review (no write/re-encode/sidecar/persistence paths) + functional review (files unchanged on disk after playback) |

- [x] Every product requirement assigned to this story maps to at least one story requirement; no other product requirement is claimed here (product R13–R14 stay with E3-S1/E3-S2, product R18–R20 with E3-S3; product R16 appears only as the shared responsiveness note S16).
- [x] Playback semantics are explicit and testable: the become-current trigger set including settle-only start (S1, S2), unmuted auto-play (S3), images excluded (S4), both toggle inputs and the full click-guard matrix (S5–S7), frozen-frame-only pause (S8), stop-on-page-away and restart-on-revisit (S9, S10), loop without auto-advance (S11).
- [x] Read-only playback is a first-class, reviewable contract: no modification of file contents (S12) and no writes of any kind — no copies, no sidecars, no playback-state persistence (S13).
- [x] Failure handling is explicit: playback failure (S14) and stale items (S15) extend E2-S2's neutral unavailable-state contract, feed navigable in both.
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run includes `--uitests` (UI-test mandate, R14 of E1-S2 — decision in Story context).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: a video auto-playing on arrival at folder open and on every paging move onto a video — playback starts only after paging settles, never mid-scroll; audio audible (unmuted) on auto-play; the spacebar toggling play/pause; a single click toggling from anywhere on the current page including the letterbox; clicks on neighbor pages, mid-gesture, and on an image page all doing nothing; a paused video showing only the frozen frame with no chrome; paging away stopping the video; paging back restarting it from the beginning; a video looping at its end without advancing the feed; the unavailable state for a `fake.mp4` and for a vanished file with the feed staying navigable throughout; and the media files byte-identical on disk after all of the above (this is a UI story — functional review is part of the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R11, R12, R15, R17; R16; RNF-02 / RNF-04; non-goals)
- [docs/decisions.md](../../decisions.md) — D7 (layering & seams), D8 (presentation & concurrency), D13 (playback semantics: auto-play, loop in place), D19 (scoped access), D20 (classification), D22 (feed paging; App-owned input path), D23 (preview seam)
- [docs/specs/e2-s2-vertical-feed-window/spec.md](../e2-s2-vertical-feed-window/spec.md) — direct predecessor (feed/window contracts S1–S11, S14–S16; S12–S13 unavailable-state contract extended here)
- [docs/specs/e2-s2-vertical-feed-window/design.md](../e2-s2-vertical-feed-window/design.md) — §4.1 (seam split: `MediaPlayerService` grows real members, `MediaPreviewService` keeps serving neighbors), §7 (display states), §10 (test strategy), §13 (handoff notes)
- [docs/specs/e2-s1-entry-media-collection/spec.md](../e2-s1-entry-media-collection/spec.md) — inherited contracts (`startIndex`, welcome state S5–S7, snapshot semantics S13)
- [docs/architecture.md](../../architecture.md) — Feed feature layout; §4 dependency rule
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E2-S3) and the E2–E5 coverage note
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
