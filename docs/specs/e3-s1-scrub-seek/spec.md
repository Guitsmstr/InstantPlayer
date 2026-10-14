# E3-S1 · Scrub & seek — Story Spec

## Story context

- **Why this story, why now.** E3's opener — the playback-controls epic ("inspect footage precisely
  without leaving the feed", [docs/backlog.md](../../backlog.md)). The walking skeleton plays a clip
  and lets the user hold on a frame, but there is no way to *move within* it: finding a moment means
  watching and re-watching. This story lands the first transport move the product spec's playback
  trio names — product R13, scrub & seek — on the surface E2-S3 deliberately left open for it.
- **What "scrub & seek" means end to end.** (Settled interview answers 1–6, bound — no
  re-litigation.) Two invocations: **drag-scrub** on a hover/mouse-move overlay control bar, and
  **keyboard seek** with ←/→. The bar appears on mouse movement over the current video page —
  playing or paused — and hides again after a short idle; it shows a progress track, a scrubber, and
  elapsed/duration labels; it is never shown on image pages. During a drag, playback pauses and the
  displayed frame follows the scrubber live; on release it resumes if it was playing before the
  drag, and stays paused with the frozen frame at the new position if it was not. During the drag,
  the displayed frame corresponds to the point under the scrubber, updating fluidly (the preview's
  updates are coalesced and bounded); on release the position lands **frame-exact** on the
  requested point. ←/→ step ±5 s per press with hold-to-repeat (like the ↑/↓ paging keys), working
  while playing and while paused and never changing the play/pause state. A click on the bar's
  progress track seeks straight to that point and never toggles play/pause — the bar's strip is
  excluded from the whole-page toggle target (E2-S3 S6/S7).
- **Amendment to E2-S3 S8 (stated plainly).** E2-S3 S8 said a pause shows "nothing but the frozen
  frame — no controls overlay, no progress indicator, no play button", carrying E2-S2 S14's
  chrome-free viewport. **This story refines that contract:** the control bar is this story's
  transport chrome — visible on demand (mouse movement over the current video page) and hidden when
  idle. When the bar is hidden — including paused-at-rest — the display shows only the frame,
  exactly as E2-S3 S8 requires; the refinement is that chrome exists but is demand-driven, never
  permanently resident. Nothing else in E2-S3 S8 changes.
- **Ratified surface (E2-S3's recorded consequence).** E2-S3 S6–S7 made the whole current page the
  click target and recorded the consequence: drag-on-video scrubbing is foreclosed, and E3-S1's
  scrubbing must live in a **hover/mouse-move overlay control bar**
  ([docs/specs/e2-s3-basic-playback/design.md](../e2-s3-basic-playback/design.md) §13, E3 handoff —
  D27). This story builds exactly that surface; drag-on-video scrubbing stays foreclosed (non-goal).
- **Product requirements carried.** product R13 only — "move its playback position to the indicated
  point" ([docs/spec.md](../../spec.md)) — cited below as `product R#`, never renumbered or
  restated as new normative text. product R16 (cross-cutting responsiveness) applies as this
  story's share via S17, per the coverage note in [docs/backlog.md](../../backlog.md). product R17
  (media files never rewritten) is an inherited no-regression contract carried via S16 — first-class
  in E2-S3, not re-claimed here. Story-scoped requirements (derivations and refinements) are
  numbered **S1…S17** in this file only.
- **Pillars.** Both pillars are engaged. **RNF-02 (performance):** this story's share of product
  R16 is concrete and visible — dragging must not stall or beachball, the live preview under the
  scrubber must stay fluid, and the release must land frame-exact without a perceptible wait (S17);
  numeric budgets are this story's design-phase output, which loads the `swift-performance` skill
  per the pillar rule (D5). **RNF-04 (security):** seek is a **read** of the already-open
  security-scoped session of the current collection (D19) — no new access paths, no writes, no
  sidecar files, no persisted positions (S16); the design loads the `swift-security` skill.
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE NOT affected.** Unlike E2-S3, whose
  decision this deliberately does not copy: with no media open, the launch-visible behavior is
  unchanged — the welcome state and its launch cost are exactly as E2-S1/E2-S2 left them — and this
  story's entire surface (the control bar, its scrubber, the ←/→ keys) exists only once media is
  open, which the UI tests cannot reach: entry remains host-driven (Open With and drag & drop), the
  standing caveat E2-S1 through E2-S3 recorded. The UI-test-covered flows are launch flows, and
  they are untouched, so the converge run keeps the default gate scope with **no `--uitests`
  obligation** for this story ([docs/development.md](../../development.md) §3). Honest caveat,
  recorded in the predecessors' form: even a `--uitests` run could not exercise scrub/seek (no
  media is open in the launch tests), so the behavior is verified by unit tests — bar visibility and
  idle-hiding policy, drag state preservation, the coalesced/immediate dispatch split, key step and routing
  semantics, the seek guard matrix, clamping and end handover — plus stakeholder functional review.
- **Inherited contracts and how each interaction composes (E2-S1–E2-S3).** Seek is a property of
  the **settled current video** — the same premise as E2-S3's settle-only auto-play (S2) and click
  guard (S7): non-current pages, pages during a paging gesture, image pages, and items in the
  neutral unavailable state take no seek input (S4, S12). E2-S3's toggle inputs stand unchanged
  except for one additive carve-out: the bar's strip is excluded from the whole-page click target
  (S11 refines S6/S7 there). E2-S3 S5–S8's toggle and frozen-frame semantics stand, refined only as
  stated above (S3). E2-S3 S9/S10 stand unchanged — paging away stops playback, revisiting restarts
  from the beginning — and a seek position is never carried across visits (S15). E2-S3 S11 (product
  R15, D26) remains the end-of-media contract; a seek that lands at the end hands over to it (S14).
  E2-S3 S12/S13's read-only, no-persistence contract extends to seek unchanged (S16), and E2-S3
  S14/S15's unavailable-state contract is untouched (S12). The keyboard path follows the established
  App-owned input precedent (D22's consequence, D28) — input delivery is design detail; this spec
  states only the visible contract.
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md) (Feed feature),
  on top of E2-S3's playback. Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a user inspecting footage, I want to drag a scrubber and see the frame under my
  cursor live, so that I can find the moment I care about without watching the whole clip.
- **US2** · As a user with my hands on the keyboard, I want ←/→ to nudge the video by a few seconds,
  so that I can fine-tune the position without reaching for the mouse.
- **US3** · As a user scanning a clip, I want to click the progress track and land straight at that
  point — without accidentally pausing or playing — so that jumping around stays one clean action.
- **US4** · As a user who wants the picture unobstructed, I want the control bar only when I reach
  for it (mouse movement) and gone when I idle, so that watching stays chrome-free.
- **US5** · As a user flipping between clips while I scrub, I want each interaction to do exactly
  one thing — seek here, toggle there, loop at the end — so that the app never surprises me.
- **US6** · As a user reviewing camera dumps and downloads, I want seeking to never touch my files
  or leave traces behind, so that I can trust the app with my media.

## Story requirements (EARS)

Numbering is story-local: **S1…S17** for this story only. Product requirements are cited as
`product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that
merely anchor product text cite it; requirements that refine or derive add a short derivation note.

### Scrub & seek surface (product R13 — settled answers 1–2)

- **S1:** WHEN the user drags the scrubber on the overlay control bar while the settled current item
  is a video
  THE SYSTEM SHALL move that video's playback position to the point under the scrubber (product R13)

*Derivation (S1):* product R13's "scrubs" invocation, on the ratified surface: E2-S3 S6–S7's
recorded consequence forecloses drag-on-video scrubbing and mandates the hover/mouse-move overlay
control bar (D27, E2-S3 design §13 handoff). The moment-to-moment semantics of the drag are
S5–S8; where the input applies at all is S12.

- **S2:** WHEN the user presses the ← or → key while the settled current item is a video
  THE SYSTEM SHALL move that video's playback position 5 seconds backward or forward respectively
  (product R13)

*Note (S2):* product R13's "otherwise seeks" invocation (settled interview answer 1); the step is
fixed at 5 s per press (answer 5) — other keys and variable step sizes are non-goals below. Input
delivery is design detail (D28's precedent; same note as E2-S3's S5). Boundary behavior is S13;
state neutrality is S10.

- **S3:** WHEN the mouse moves over the current video page of a video — whether it is playing or
  paused
  THE SYSTEM SHALL show the overlay control bar (progress track, scrubber, and elapsed/duration
  labels) and hide it again after a short idle without mouse movement

*Derivation (S3):* settled interview answer 2, and the plain amendment of E2-S3 S8 recorded in
Story context — the bar is demand-driven transport chrome; at rest (bar hidden) the frozen frame is
still the only indication. Two recorded consequences: **(a)** the bar stays visible while the user
interacts with it — an in-progress drag is not idle, and hiding the scrubber mid-drag would break
S5–S8, so the idle timer is suspended for the drag's duration and restarts after release;
**(b)** visibility is mouse-driven only — a keyboard seek (S2) does not show the bar by itself (no
mouse movement is involved); seek feedback is the frame and position themselves. (b) is recorded
as a reading of the settled rule — its stated trigger is mouse movement — not as an added or
forbidden trigger; the stakeholder can veto it at the approval gate. Bar contents are exactly the
four named elements (the rest is non-goal); the idle timeout's numeric value is design-phase output
(RNF-02 budget in design).

- **S4:** WHEN the current item is an image
  THE SYSTEM SHALL show no control bar, and no seek input has any effect

*Derivation (S4):* settled interview answer 2 ("never shown on image pages") — images have no
playback semantics (E2-S3 S4's principle carries), so there is no bar and nothing to seek.
Reinforced by S12's guard.

### Scrubbing gesture semantics (settled answers 3–4)

- **S5:** WHEN a scrub drag is in progress
  THE SYSTEM SHALL pause the video's playback and update the displayed frame live to the position
  under the scrubber

*Derivation (S5):* settled interview answer 3 — playback pauses for the drag and the frame tracks
the scrubber live (the live preview). This pause is gesture-scoped, not a user toggle: it does not
change the "was playing before" state that S8 restores.

- **S6:** WHEN the scrubber is being dragged
  THE SYSTEM SHALL keep the displayed frame corresponding to the point under the scrubber, with
  updates dispatched coalesced and bounded so the preview stays fluid for the whole drag

*Derivation (S6):* settled interview answer 4's first half — during the drag, the preview is what the
user is reading, so the frame must track the point under the scrubber while staying fluid. S7 makes
the release authoritative.

*Converge amendment (2026-10-13, coordinator-ratified, stakeholder functional review):* S6's earlier
wording — "fast, tolerant seeks … accepting an approximate position while the drag lasts" — described
an approximate landing that in practice snapped to the nearest sync sample, so a drag showed only a
few keyframe-steppy frames instead of the frame under the scrubber. The visible contract is now the
frame under the scrubber, updated fluidly; how the updates are dispatched (coalesced, bounded) is
design detail. S-numbering and product-R citations are unchanged.

- **S7:** WHEN the scrub drag is released
  THE SYSTEM SHALL settle the playback position frame-exactly on the point indicated by the
  scrubber

*Derivation (S7):* settled interview answer 4's second half — the release is the commit point: the
preview positions of S6 are replaced by one frame-exact landing at the requested point, and S8's
state decision applies to that landing.

- **S8:** WHEN the scrub drag is released
  THE SYSTEM SHALL resume playback if the video was playing before the drag began, and SHALL leave
  it paused with the frozen frame at the new position if it was paused before

*Derivation (S8):* settled interview answer 3 — the drag never changes the user's play/pause
intent. If it was paused, the release shows the frozen frame at the new position (E2-S3 S8's pause
contract, at the new position — S7's frame-exact landing).

### Keyboard stepping (settled answer 5)

- **S9:** WHEN the user holds ← or → down
  THE SYSTEM SHALL repeat the 5-second step (S2) for as long as the key auto-repeats — the same
  hold-to-repeat behavior as the ↑/↓ paging keys

*Derivation (S9):* settled interview answer 5. Parity with the paging keys' frozen auto-repeat
behavior (D22) — this story changes no paging semantics; repeated steps near a boundary clamp
(S13).

- **S10:** WHEN a seek completes while the video is playing or while it is paused
  THE SYSTEM SHALL leave the play/pause state unchanged — a playing video continues from the new
  position, a paused one shows the frozen frame at the new position

*Derivation (S10):* settled interview answer 5 ("play/pause state unchanged by a seek"). The same
principle governs the drag (S8) and the track click (S11); S14's end handover is the one place a
seek meets the loop contract.

### Track click (settled answer 6)

- **S11:** WHEN the user clicks the progress track of the control bar
  THE SYSTEM SHALL move the playback position straight to the clicked point and SHALL NOT toggle
  play/pause — the control bar's strip is excluded from the whole-page toggle target (E2-S3 S6/S7)

*Derivation (S11):* settled interview answer 6. The carve-out from E2-S3 S6's whole-page click
target is limited to the bar's strip: clicks anywhere else on the current page keep toggling
exactly as E2-S3 S6/S7 specify. "Never toggles" also means the click preserves the play/pause state
(S10's principle).

### Seek applicability & guard (composition with E2-S3 S2, S7, S14, S15)

- **S12:** WHEN a seek input (scrub drag, track click, or keyboard seek) is directed at anything
  other than the settled current video — a non-current page, a page while a paging gesture is in
  flight, an image page, or an item showing the neutral unavailable state
  THE SYSTEM SHALL treat the input as a no-op

*Derivation (S12):* seek applies only to the settled current video — the same guard premise as
E2-S3 S7's click matrix (settled interview answer 1's consequence, carried by the brief's
composition rule). The unavailable case (E2-S3 S14/S15) is this story's derivation: such an item
has no playback to seek, so it shows no bar (S3 presupposes a playing or paused video) and seek
input is silently ignored — the neutral-state, feed-navigable contract there is preserved
unchanged. Guarded inputs do nothing quietly, never beep (D28's input-policy principle carries).

### Position bounds & end handover (product R15 context)

- **S13:** WHEN a seek would move the position before the video's beginning or past its end
  THE SYSTEM SHALL clamp the position to the beginning or to the end respectively

*Derivation (S13):* settled (seek position clamps within the video's beginning/end) — keyboard
steps near a boundary (S9's repeated steps), drag positions, and track clicks past the extremes all
clamp rather than error.

- **S14:** WHEN a seek lands the position at the video's end — or playback plays into the end
  THE SYSTEM SHALL hand over to the loop contract: the same video restarts from its beginning, and
  the feed never automatically advances (product R15; E2-S3 S11, D26)

*Derivation (S14):* settled — "a seek that lands at (or plays into) the end hands over to the
existing loop contract — restart the same video, never auto-advance". "Plays into the end" is
E2-S3 S11's unchanged path; "lands at the end" is this story's new entry into the same contract —
a seek to the end position is an end-of-media event, so the loop takes over instead of parking on
the last frame. The handover supplies the position (the beginning); this story's state rules supply
the play state: a playing video continues from the restarted beginning (loop in place), a paused
one stays paused there (the frozen frame — S8's and S10's principle). Never auto-advance
(product R15).

### Revisiting a seeked video (E2-S3 S9/S10 unchanged)

- **S15:** WHEN the user pages away from a video whose position was moved by a seek and pages back
  to it
  THE SYSTEM SHALL restart it from its beginning (E2-S3 S10, auto-play per E2-S3 S1) — the seek
  position is not carried across visits

*Derivation (S15):* E2-S3 S9/S10 stand unchanged (no resume, nothing carried across visits); this
story adds no memory of positions. Combined with S16 there is nowhere a position could be kept —
deterministic restarts remain the v1 semantics.

### Read-only seek (product R17 — inherited no-regression contract)

- **S16:** WHEN the user scrubs or seeks
  THE SYSTEM SHALL write nothing to disk and modify nothing — no rewrite of the media file, no
  sidecar or derived file, and no persisted playback or seek position (product R17; E2-S3 S12/S13
  unchanged)

*Derivation (S16):* product R17 is E2-S3's first-class requirement and an inherited no-regression
contract here, not a new claim: seek is a read through the already-open security-scoped session
(D19) — no new access paths, the session is not re-derived — and persisting a position would
contradict E2-S3 S13 (no playback-state persistence exists in v1, which also forecloses resume —
S15). RNF-04's posture is unchanged.

### Responsiveness (product R16 — this story's share)

- **S17:** WHEN the user scrubs, clicks the progress track, or seeks from the keyboard
  THE SYSTEM SHALL keep the interface smooth and responsive — no stalls and no beachballing, with a
  fluid live preview throughout the drag (product R16, RNF-02)

*Note (S17):* product R16 is deliberately not assigned to any single story
([docs/backlog.md](../../backlog.md) coverage note) — S17 states this story's share of the
responsiveness budget: the drag preview (S6), the frame-exact landing (S7), and the key steps (S2,
S9) all happen without stalling the interface. Numeric budgets are set in this story's design
(RNF-02), which loads the `swift-performance` skill.

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in
[docs/spec.md](../../spec.md) apply unchanged):

- **Playback speed** (E3-S2) — product R14.
- **Volume & mute** (E3-S3) — product R18–R20. Videos keep playing unmuted (E2-S3 S3); the
  hardware/system output volume is the user's control until E3-S3.
- **Drag-on-video scrubbing** — foreclosed by E2-S3 S6/S7's whole-page click target (its recorded
  consequence, ratified in D27 / E2-S3 design §13): the hover/mouse-move overlay control bar is the
  one scrubbing surface.
- **Extra seek keys and variable steps** — the step is fixed at ±5 s per press with hold-to-repeat
  (settled answer 5); Home/End, J/K/L, modifier steps, and any other seek invocation are not
  claimed.
- **Bar contents beyond the named four** — progress track, scrubber, elapsed and duration labels
  (settled answer 2); hover thumbnails, chapter markers, buffered ranges, and any other transport
  chrome are not claimed.
- **Double-click** — no meaning in v1 (E2-S3's recorded consequence stands); native fullscreen entry
  remains the green button / ⌃⌘F (E2-S2 S11).
- **Resume positions** — across paging (E2-S3 S10, S15) or across launches (E2-S3 S13, S16);
  seeks are forgotten on revisit and on relaunch.
- **Auto-advance** — foreclosed by product R15 (S14): at the end the same video restarts; feed
  advancement is always user-driven.
- **Images and seek** — no seek semantics for images (S4); their display contract is unchanged.
- **Play/pause, auto-play, and loop semantics** — unchanged from E2-S3 (its S1–S3, S5–S8, S11);
  this story moves the position and refines only the chrome contract (S3).
- **Ordering** (E4-S1) — product R21–R22; **live folder sync** (E4-S2) — product R23–R26;
  **list view & operations** (E5-S1, E5-S2) — product R27–R33.
- **Feed navigation & window behavior** — unchanged from E2-S2 (its S4–S11); this story adds
  position control under the current item and alters no paging, ordering, or window semantics.
- **Network** — excluded from v1 entirely (D9); seek reads the local file only.

## Acceptance criteria

Product-requirement coverage map — the one product requirement assigned to this story (product R13
of [docs/backlog.md](../../backlog.md)) maps to a verifiable story outcome; product R16 is carried
as a cross-cutting share via S17 and product R17 as an inherited no-regression contract via S16 —
neither is claimed as this story's own:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R13 (scrub/seek to the indicated point) | S1 (drag on the bar), S2 (keyboard ±5 s), S5–S8 (drag: pause + live fluid preview, frame-exact release, state restoration), S11 (track click), S12 (guard matrix), S13–S14 (clamping, end handover) | unit tests (seek policy: step size, hold-to-repeat, guard matrix, clamping, end handover, state preservation, coalesced/immediate dispatch split) + functional review (drag, click, keys, live preview, frame-exact landing) |
| R16 (smooth & responsive) — cross-cutting share via S17, not claimed | S17 — no stalls or beachballing during scrub/seek; fluid live preview | validator performance review (RNF-02; numeric budgets from this story's design) + functional review (drag stays fluid) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S16 — seek writes nothing, persists nothing; no new access paths (D19) | validator security review (no write/sidecar/persistence paths; session not re-derived) + functional review (files byte-identical on disk after scrubbing) |

- [x] Every product requirement assigned to this story maps to at least one story requirement; no
  other product requirement is claimed here (product R14 stays with E3-S2, product R18–R20 with
  E3-S3; product R16 appears only as the shared responsiveness note S17; product R17 appears only
  as the inherited no-regression contract S16).
- [x] The E2-S3 S8 amendment is stated plainly (Story context; S3): chrome is demand-driven, and
  hidden-at-rest — paused included — still shows only the frozen frame.
- [x] Scrub & seek semantics are explicit and testable: both invocations (S1, S2), bar
  visibility and contents with the drag-visible/idle-hidden policy (S3), images excluded (S4), drag
  pause with live frame tracking (S5), a fluid frame-tracking preview during the drag vs
  frame-exact landing on release (S6, S7), state restoration on release (S8), keyboard step with
  hold-to-repeat and
  state-neutrality (S9, S10), track click without toggle and the toggle-target carve-out (S11),
  the full applicability guard (S12), clamping (S13), end handover to loop without auto-advance
  (S14), and no position carried across visits (S15).
- [x] Read-only seek is a reviewable contract: nothing written or persisted (S16); the RNF-04
  posture is unchanged (D19's already-open session).
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json
  <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run keeps the default
  gate scope (UI-test mandate decision in Story context: flows are not affected).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: the bar
  appearing on mouse movement over a playing and a paused video page and hiding again after idle;
  never appearing on an image page; dragging the scrubber pausing playback with the frame tracking
  live and fluidly; releasing resuming a previously-playing video and leaving a previously-paused
  one frozen at the frame-exact new position; clicking the progress track seeking there without
  toggling play/pause while clicks elsewhere on the page still toggle; ←/→ stepping ±5 s with
  hold-to-repeat, working while playing and while paused without changing the state; seeks near
  either end clamping; a seek to the very end restarting the same video without advancing the feed;
  paging away and back restarting from the beginning; keyboard seek doing nothing on a non-current
  page, mid-gesture, and on an image page; and the media files byte-identical on disk after all of
  the above (this is a UI story — functional review is part of the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R13; R11, R12, R15, R17 context;
  R16; RNF-02 / RNF-04; non-goals)
- [docs/decisions.md](../../decisions.md) — D19 (scoped access), D20 (classification), D22 (feed
  paging; App-owned input path), D25 (playback sessions), D26 (loop contract), D27 (chrome-free
  rendering; the ratified overlay-bar surface), D28 (playback input)
- [docs/specs/e2-s3-basic-playback/spec.md](../e2-s3-basic-playback/spec.md) — direct predecessor
  (S5–S8 toggle/click-guard/frozen-frame, refined by S3 and S11 here; S9/S10 carried by S15; S11
  carried by S14; S12/S13 carried by S16; S14/S15 composed by S12)
- [docs/specs/e2-s3-basic-playback/design.md](../e2-s3-basic-playback/design.md) — §13 (E3
  handoff: scrubbing lives in the hover/mouse-move overlay control bar)
- [docs/specs/e2-s2-vertical-feed-window/spec.md](../e2-s2-vertical-feed-window/spec.md) —
  feed/window contracts (paging settle, chrome-free viewport, unavailable state)
- [docs/specs/e2-s1-entry-media-collection/spec.md](../e2-s1-entry-media-collection/spec.md) —
  inherited contracts (welcome state, snapshot semantics)
- [docs/architecture.md](../../architecture.md) — Feed feature layout; §4 dependency rule
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E3-S1) and the E2–E5 coverage note
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
