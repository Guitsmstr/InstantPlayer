# E3-S2 · Playback speed — Story Spec

## Story context

- **Why this story, why now.** E3's playback-controls epic continues ("inspect footage precisely
  without leaving the feed", [docs/backlog.md](../../backlog.md)). E3-S1 landed scrub & seek on the
  demand-driven overlay control bar; this story lands the second member of the product spec's
  playback trio — product R14, playback speed — which D13 named as app-provided transport from the
  start ("play/pause, scrub/seek, and playback speed are app-provided transport"). Reviewing camera
  dumps at pace still means watching every clip at 1×: speed is how a reviewer gets through a batch
  or slows down for a detail without leaving the feed. E3-S1's non-goal "Playback speed (E3-S2) —
  product R14" is landed here and nowhere else.
- **What "playback speed" means end to end.** (Settled interview answers 1–5, bound — no
  re-litigation.) The selection surface is a **speed menu on the overlay control bar** (the E3-S1
  bar is the ratified home for transport chrome) **plus keyboard steps** through the presets. The
  presets are exactly five — **0.25×, 0.5×, 1×, 1.5×, 2×** — and nothing outside that ladder is
  selectable. The selected speed applies to the current video and **carries across subsequently
  viewed videos until it is changed**; the app **starts at 1× after relaunch** (no persistence —
  persisted preferences are E3-S3's territory for volume). The bar shows a **speed badge only when
  the selected speed differs from 1×**. The `[` and `]` keys step the speed down/up through the
  presets, and a held key repeats the step (the same repeat parity as the ↑/↓ paging keys and the
  ←/→ seek keys).
- **Amendment to E3-S1's bar-contents contract (stated plainly).** E3-S1 S3's note and non-goal made
  the bar "exactly the four named elements" — progress track, scrubber, elapsed and duration labels
  — and its design §13 handoff recorded that the bar strip is the ratified home for future transport
  chrome, "each addition its own spec decision". **This story is that decision for speed:** the bar
  gains a speed control (the settled "speed menu", S1) and a speed badge (S4), alongside the four
  existing elements. Nothing else in E3-S1's bar contract changes — demand-driven visibility on mouse
  movement, idle-hide, structural absence on image pages, and the strip's carve-out from the
  whole-page toggle target all carry unchanged (S3; the speed control is part of the strip, so
  interacting with it never toggles play/pause).
- **Evolution of E3-S1's "never changes rate" seek contract (stated plainly).** E3-S1 S10/D32
  recorded that a seek never changes the playback rate — invisible phrasing in a fixed-rate app, but
  its only honest reading once a speed exists is **"a seek never changes the *selected* speed"**:
  no seek (scrub, track click, or keyboard) resets the speed to 1× (S13), and the end-of-video loop
  restarts at the selected speed (S14). Nothing else in E3-S1's seek semantics changes.
- **Product requirements carried.** product R14 only — "apply it to the current video"
  ([docs/spec.md](../../spec.md)) — cited below as `product R#`, never renumbered or restated as new
  normative text. product R16 (cross-cutting responsiveness) applies as this story's share via S18,
  per the coverage note in [docs/backlog.md](../../backlog.md). product R17 (media files never
  rewritten) is an inherited no-regression contract carried via S17 — first-class in E2-S3, not
  re-claimed here. Story-scoped requirements (derivations and refinements) are numbered
  **S1…S18** in this file only.
- **Pillars.** Both pillars are engaged. **RNF-02 (performance):** speed changes must be instant and
  stall-free (S18), and a video must play at the selected speed from its first frame with no
  momentary 1× flash and no additional wait on top of R11's no-perceptible-wait promise (S12);
  numeric budgets are this story's design-phase output, which loads the `swift-performance` skill
  per the pillar rule (D5). **RNF-04 (security):** the speed selection is session state only — speed
  input is a **read** of the already-open security-scoped session of the current collection (D19),
  with no new access paths, no writes, no sidecar files, and no persisted preference (S9, S17); the
  design loads the `swift-security` skill.
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE NOT affected.** Same decision and same
  reasoning as E3-S1's: with no media open, the launch-visible behavior is unchanged — the welcome
  state and its launch cost are exactly as E2-S1/E2-S2 left them — and this story's entire surface
  (the bar's speed control and badge, the `[`/`]` keys) exists only once media is open, which the UI
  tests cannot reach: entry remains host-driven (Open With and drag & drop), the standing caveat
  E2-S1 through E3-S1 recorded. The UI-test-covered flows are launch flows, and they are untouched,
  so the converge run keeps the default gate scope with **no `--uitests` obligation** for this story
  ([docs/development.md](../../development.md) §3). Honest caveat, in the predecessors' form: even a
  `--uitests` run could not exercise speed selection (no media is open in the launch tests), so the
  behavior is verified by unit tests — the preset ladder and stepping policy, boundary behavior and
  hold-to-repeat, the guard matrix, carry-across-visits semantics, speed preservation across seeks
  and the loop, and start-at-speed — plus stakeholder functional review.
- **Inherited contracts and how each interaction composes (E2-S1–E3-S1).** Speed is a property of
  the **settled current video** — the same premise as E3-S1's seek guard (its S12): non-current
  pages, pages during a paging gesture, image pages, and items in the neutral unavailable state take
  no speed input and leave the selection unchanged (S16). E3-S1's bar contract stands, amended only
  as stated above (its S3). E3-S1's seek semantics stand, evolved only as stated above (its S10 —
  S13 here), and its S15 stands unchanged: a seek position restarts on revisit, while the speed
  selection deliberately carries (S8) — position and speed are independent axes, the asymmetry is
  the settled answer 3. E2-S3's auto-play (S1), settle-only start (S2), toggle and frozen-frame
  semantics (S5–S8), paging-away stops playback / revisit restarts (S9/S10), loop (S11, product R15,
  D26), read-only posture (S12/S13 → S17 here), and unavailable-state contract (S14/S15) are all
  untouched. The keyboard path follows the established App-owned input precedent (D22's consequence,
  D28's feed-key router, D34's frozen-table row pattern) — input delivery is design detail; this
  spec states only the visible contract.
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md) (Feed feature),
  on top of E3-S1's playback and bar. Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a user reviewing a batch of clips, I want to watch at 2× (or 1.5×) so that I get
  through the footage faster without scrubbing past everything.
- **US2** · As a user examining a detail, I want to slow to 0.5× or 0.25× so that I see exactly what
  happens in the moment I care about.
- **US3** · As a user with my hands on the keyboard, I want `[` and `]` to step the speed so that I
  never reach for the mouse to change pace.
- **US4** · As a user flipping through a camera dump at pace, I want my chosen speed to carry to the
  next clip so that I can review the whole batch without re-setting it every time.
- **US5** · As a user who wants the picture unobstructed, I want to see the speed only when it is
  not 1×, so that default watching stays chrome-free.
- **US6** · As a user who cares about audio, I want sped-up and slowed-down clips to still sound
  natural — no chipmunk voices — so that altered speeds stay usable.
- **US7** · As a user reviewing my own media, I want speed changes to never touch my files or leave
  traces behind, so that I can trust the app with my media.

## Story requirements (EARS)

Numbering is story-local: **S1…S18** for this story only. Product requirements are cited as
`product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that
merely anchor product text cite it; requirements that refine or derive add a short derivation note.

### Speed selection surface (product R14 — settled answers 1, 2, 4)

- **S1:** WHEN the user selects a different playback speed from the speed menu on the overlay
  control bar while the settled current item is a video
  THE SYSTEM SHALL apply it to that video (product R14)

*Derivation (S1):* product R14's anchor, on the ratified surface (settled answer 1 — the E3-S1 bar
strip is the home for transport chrome, D27/E3-S1 design §13 handoff; this story is the recorded
"its own spec decision" for speed). The menu's presentation form (popover, cycling button, …) and
its copy are UI detail, design-phase output; "speed menu" is the settled surface name. The
moment-to-moment semantics are S10–S12; the selection's scope is S8–S9; where speed input applies at
all is S16.

- **S2:** WHEN the playback speed is changed
  THE SYSTEM SHALL set it to exactly one of five presets — 0.25×, 0.5×, 1×, 1.5×, and 2× — with no
  value outside that ladder available (settled answer 2)

*Note (S2):* settled answer 2 fixes the ladder at exactly five presets; custom values, a continuous
slider, and finer steps are non-goals below. The step keys (S5) and the menu (S1) are two surfaces
over the same ladder and the same single selection.

- **S3:** WHEN the overlay control bar is shown for the current video page
  THE SYSTEM SHALL include a speed control and a speed badge alongside its progress track, scrubber,
  and elapsed/duration labels

*Derivation (S3):* the plain amendment of E3-S1's bar-contents contract recorded in Story context —
E3-S1's four named elements were "the whole contract" *for E3-S1*, and its design §13 handoff
reserved the bar strip for future transport chrome, each addition its own spec decision; this
addition is that decision (settled answers 1 and 4). Everything else about the bar carries
unchanged: visibility is demand-driven (E3-S1 S3), it is structurally absent on image pages (E3-S1
S4), and the whole strip stays excluded from the whole-page toggle target (E3-S1 S11) — so a click
or selection on the speed control never toggles play/pause.

- **S4:** WHEN the overlay control bar is shown
  THE SYSTEM SHALL show the speed badge only when the selected speed differs from 1×, the badge
  identifying the selected speed

*Derivation (S4):* settled answer 4 — "only when the selected speed differs from 1×" cuts both ways:
at 1× there is no badge (default watching shows nothing extra), and at any other preset the badge
identifies it (e.g. `2×`). The badge's exact wording and styling are UI detail.

### Keyboard stepping (settled answer 5)

- **S5:** WHEN the user presses the `[` or `]` key while the settled current item is a video
  THE SYSTEM SHALL step the selected speed one preset down or up respectively through the ladder of
  S2 (product R14)

*Note (S5):* settled answer 5's invocation — the plain `[` and `]` keys. As with E3-S1's S2, input
delivery is design detail (D28's precedent); boundary behavior is S7; eligibility is S16; state
neutrality in the play/pause axis is S10/S11's principle (a speed step never toggles play/pause).
The modifier policy follows the frozen router table's established rows (D28, D34): ⌘/⌥/⌃
combinations pass through so system shortcuts are never robbed, and ⇧ alone does not modify.

- **S6:** WHEN the user holds `[` or `]` down
  THE SYSTEM SHALL repeat the one-preset step (S5) for as long as the key auto-repeats — the same
  hold-to-repeat behavior as the ↑/↓ paging keys and the ←/→ seek keys (settled answer 5)

*Derivation (S6):* settled answer 5's "held key repeats steps (same repeat parity as paging and
keyboard seek)" — the D22/D34 repeat parity carries; repeated steps near a ladder end clamp (S7).

- **S7:** WHEN a step would move the selection past 0.25× or past 2×
  THE SYSTEM SHALL remain at 0.25× or 2× respectively — the preset ladder has ends and never wraps

*Derivation (S7):* recorded as a reading of the settled rules, not as an interview answer — "step
down/up through the presets" describes a bounded ordered ladder, and the established stepping-input
precedent clamps at its bounds (E3-S1 S13) rather than wrapping; wrap-around is not adopted. The
stakeholder can veto this reading at the approval gate.

### Speed scope & persistence (settled answer 3)

- **S8:** WHEN the user selects a different speed
  THE SYSTEM SHALL apply it to the current video and to every subsequently viewed video until it is
  changed again (product R14; settled answer 3)

*Derivation (S8):* settled answer 3 — the selection is app-session state, not per-video state: it
carries across paging, across revisits, and across a newly opened folder within the session until
the user changes it. The deliberate asymmetry with positions (E3-S1 S15: a seek position is not
carried across visits) is the settled contract — speed carries, position restarts (S12 covers how a
restart begins).

- **S9:** WHEN the app is relaunched
  THE SYSTEM SHALL start at 1× — the previous session's speed selection is not restored (settled
  answer 3)

*Derivation (S9):* settled answer 3's "the app starts at 1× after relaunch (no persistence)" —
persisted preferences are explicitly deferred (E3-S3's territory for volume, product R20), so no
speed preference is written or read anywhere (S17).

### Applying the selected speed

- **S10:** WHEN the user selects a different speed while the current video is playing
  THE SYSTEM SHALL change its playback rate immediately, with no restart and no change of the
  playback position (product R14)

*Derivation (S10):* "selecting a speed while a video is playing takes effect immediately" — the
change is a rate change only; the video keeps playing from the same frame at the new pace. S12
supplies the no-flash/no-added-wait half on the start path; S18 the responsiveness budget.

*Composition note (S10):* during an E3-S1 scrub drag, playback is paused gesture-scoped (its S5), so
a speed selection made mid-drag falls under S11's paused path — it is remembered and takes effect
when the drag ends and playback resumes (its S8), needing no separate rule. This is recorded as a
composition reading; the alternative — consuming speed input mid-drag, as D34 declined to pass
keyboard seeks through mid-drag — is not adopted because that rationale ("the release lands on the
scrubber's point regardless") does not transfer to speed, which the release does not overwrite. The
stakeholder can veto this reading at the approval gate.

- **S11:** WHEN the user selects a different speed while the current video is paused
  THE SYSTEM SHALL remember the selection and play at that speed when playback resumes

*Derivation (S11):* "while paused, the selection is remembered and applies on resume" — the frozen
frame is unchanged by the selection (E2-S3 S8's pause contract stands), and the resume is the first
observable moment of the new speed. The same path covers the resume after a scrub drag (E3-S1 S8)
and after a seek (E3-S1 S10).

- **S12:** WHEN a video starts playing — auto-play on arrival, or the restart on revisit (E2-S3
  S1/S10) — or restarts at its end (S14)
  THE SYSTEM SHALL play it at the selected speed from its first frame, with no momentary 1×
  playback and no additional wait (product R11; RNF-02)

*Derivation (S12):* the start-at-selected-speed rule ("when a video starts … it plays at the
selected speed from the start — no momentary 1× flash, no additional wait"). R11's
no-perceptible-wait promise is untouched and not re-claimed; this story adds only that the selected
speed is part of "ready to play", not a follow-up adjustment — a visible 1× beat before the speed
kicks in is a defect, not a trade-off.

### Speed preservation across seeks and loops (E3-S1's "never changes rate" contract, evolved)

- **S13:** WHEN a seek (scrub drag, track click, or keyboard seek) completes on the current video
  THE SYSTEM SHALL leave the selected speed unchanged — no seek resets it to 1× — and SHALL leave
  the play/pause state unchanged (E3-S1 S10, evolved; product R13 context)

*Derivation (S13):* the plain evolution recorded in Story context: E3-S1's "a seek never changes the
rate" reads as "never changes the *selected* speed" now that one exists. A playing video continues
from the new position at the selected speed, a paused one shows the frozen frame there (E3-S1 S10
unchanged), and the resume paths of S11 play at the selected speed. Nothing else in E3-S1's seek
semantics is touched.

- **S14:** WHEN the current video reaches its end and loops (product R15; E2-S3 S11, E3-S1 S14,
  D26)
  THE SYSTEM SHALL restart the same video at the selected speed — the loop preserves it, and the
  feed never automatically advances

*Derivation (S14):* "the loop stays at the selected speed" — the end-of-media contract (restart the
same video from its beginning, never auto-advance) is untouched; only its rate is specified, so a
batch reviewed at 2× loops at 2× without re-selection.

### Audio at altered speeds

- **S15:** WHEN the current video plays at any preset other than 1×
  THE SYSTEM SHALL keep its audio natural-sounding — pitch-corrected, without the chipmunk/slowed
  distortion of naive rate change

*Derivation (S15):* the stakeholder's observable quality expectation ("audio should stay
pitch-corrected/natural — no chipmunk effect"), stated as what is observable at the gate: voices and
music keep their pitch at 0.25× and 2× alike. Exact audio-processing technique is design detail.

### Speed applicability & guard (quiet consumption; D28's guard matrix)

- **S16:** WHEN a speed input (a menu selection or a `[`/`]` key press) is directed at anything other
  than the settled current video — a non-current page, a page while a paging gesture is in flight,
  an image page, or an item showing the neutral unavailable state
  THE SYSTEM SHALL treat the input as a quiet no-op, leaving the selected speed unchanged and
  producing no sound, no visual change, and no error

*Derivation (S16):* the established quiet-consumption pattern (D28's guard matrix, E3-S1 S12's
premise) extended to speed: images have no playback semantics (E2-S3 S4, E3-S1 S4), so speed actions
there leave state unchanged — no sound, no visual change, no error — and a mid-gesture page has an
undetermined destination (E2-S3 S2). The bar's speed control is only reachable on the bar of the
current video page (E3-S1 S3/S4), so the guard is keyboard-led in practice; one guard matrix decides
both input families (D28). Guarded inputs are consumed and quiet, never beep.

### Read-only speed (product R17 — inherited no-regression contract)

- **S17:** WHEN the user changes or steps the playback speed
  THE SYSTEM SHALL write nothing to disk and modify nothing — no rewrite of the media file, no
  sidecar or derived file, and no persisted speed preference (product R17; E2-S3 S12/S13, E3-S1 S16
  unchanged)

*Derivation (S17):* product R17 is an inherited no-regression contract here, not a new claim: speed
is a read through the already-open security-scoped session (D19) — no new access paths, the session
is not re-derived — and persisting the speed would contradict S9's settled no-persistence scope.
RNF-04's posture is unchanged.

### Responsiveness (product R16 — this story's share)

- **S18:** WHEN the user changes the speed from the menu or the keyboard
  THE SYSTEM SHALL apply it instantly and keep the interface smooth and responsive — no stalls and
  no beachballing (product R16, RNF-02)

*Note (S18):* product R16 is deliberately not assigned to any single story
([docs/backlog.md](../../backlog.md) coverage note) — S18 states this story's share of the
responsiveness budget: the rate change itself (S10), rapid repeated steps (S6), and the
start-at-speed promise (S12) all happen without stalling the interface. Numeric budgets are set in
this story's design (RNF-02), which loads the `swift-performance` skill.

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in
[docs/spec.md](../../spec.md) apply unchanged):

- **Volume & mute** (E3-S3) — product R18–R20. Videos keep playing unmuted (E2-S3 S3); the
  hardware/system output volume is the user's control until E3-S3.
- **Speed persistence** — explicitly not this story (settled answer 3): relaunch starts at 1× (S9)
  and nothing is written (S17). v1's first persisted preference is E3-S3's volume/mute (product
  R20); a persisted speed, if ever wanted, belongs with that territory.
- **Speeds outside the preset ladder** — exactly 0.25×/0.5×/1×/1.5×/2× (settled answer 2); no
  custom values, continuous slider, finer steps, or user-defined presets.
- **Extra speed keys** — only `[` and `]` step the ladder (settled answer 5); there is no dedicated
  reset-to-1× key, no numeric shortcuts, and no J/K/L-style speed hold — other invocations are not
  claimed.
- **Image speed semantics** — images have no playback speed (S16); their display contract is
  unchanged (E2-S2's chrome-free viewport).
- **Bar contents beyond this story's additions** — the bar is now the four E3-S1 elements plus the
  speed control and speed badge (S3); hover thumbnails, chapter markers, buffered ranges, and any
  other transport chrome remain unclaimed, and volume/mute controls are E3-S3's addition to the
  same strip.
- **Seek and position semantics** — unchanged from E3-S1 apart from the stated rate evolution
  (S13): frame-exact landings, ±5 s steps, clamping, and end handover stand as written; no resume
  positions across paging (E3-S1 S15) or launches.
- **Auto-advance** — foreclosed by product R15 (S14): at the end the same video restarts; feed
  advancement is always user-driven.
- **Play/pause, auto-play, and loop semantics** — unchanged from E2-S3 (its S1–S3, S5–S8, S11); this
  story selects the rate and preserves it, and alters no toggle, start, or loop behavior.
- **Ordering** (E4-S1) — product R21–R22; **live folder sync** (E4-S2) — product R23–R26;
  **list view & operations** (E5-S1, E5-S2) — product R27–R33.
- **Feed navigation & window behavior** — unchanged from E2-S2 (its S4–S11); this story adds rate
  selection under the current item and alters no paging, ordering, or window semantics.
- **Network** — excluded from v1 entirely (D9); speed reads the local file only.

## Acceptance criteria

Product-requirement coverage map — the one product requirement assigned to this story (product R14
of [docs/backlog.md](../../backlog.md)) maps to a verifiable story outcome; product R16 is carried
as a cross-cutting share via S18 and product R17 as an inherited no-regression contract via S17 —
neither is claimed as this story's own:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R14 (apply the selected speed to the current video) | S1 (menu selection), S2 (five presets), S5–S7 (keyboard stepping, repeat, ladder ends), S8 (carries until changed), S10–S11 (immediate while playing, remembered while paused), S13–S14 (preserved across seeks and the loop) | unit tests (speed policy: preset ladder, stepping and boundary clamping, hold-to-repeat, guard matrix, carry semantics, seek/loop preservation, start-at-speed) + functional review (menu, keys, badge, immediate apply, carry across clips) |
| R16 (smooth & responsive) — cross-cutting share via S18, not claimed | S18 — speed changes instant and stall-free; S12 — no 1× flash and no added wait at start | validator performance review (RNF-02; numeric budgets from this story's design) + functional review (rapid speed changes stay fluid; clips start already at speed) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S17 — speed writes nothing and persists nothing; no new access paths (D19); S9 — relaunch at 1× | validator security review (no write/sidecar/persistence paths; session not re-derived) + functional review (files byte-identical on disk; relaunch starts at 1×) |

- [x] Every product requirement assigned to this story maps to at least one story requirement; no
  other product requirement is claimed here (product R18–R20 stay with E3-S3; product R16 appears
  only as the shared responsiveness note S18; product R17 appears only as the inherited
  no-regression contract S17).
- [x] The two contract changes are stated plainly in Story context: E3-S1's bar-contents contract is
  deliberately extended by the speed control and badge (S3), and its "never changes rate" seek
  contract is evolved to "never changes the *selected* speed" (S13, S14) — nothing else in either
  contract changes.
- [x] Speed semantics are explicit and testable: both invocations (S1, S5), the exact five-preset
  ladder (S2), the bar additions and badge visibility rule (S3, S4), keyboard stepping with
  hold-to-repeat and ladder ends (S5–S7), carry-across-visits-until-changed (S8), no persistence
  across relaunch (S9), immediate application while playing and remembered application while paused
  (S10, S11), start-at-selected-speed with no 1× flash and no added wait (S12), preservation across
  every seek and the loop (S13, S14), pitch-corrected audio (S15), and the full quiet-consumption
  guard (S16).
- [x] Read-only speed is a reviewable contract: nothing written or persisted (S17, S9); the RNF-04
  posture is unchanged (D19's already-open session).
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json
  <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run keeps the default gate
  scope (UI-test mandate decision in Story context: flows are not affected).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: selecting
  each preset from the bar's speed menu and seeing it applied immediately on a playing video;
  selecting while paused and seeing it applied on resume; the badge appearing whenever the speed
  differs from 1× and vanishing at 1×; `[`/`]` stepping through the ladder with hold-to-repeat and
  clamping at 0.25× and 2×; the speed carrying to the next clip and across revisits and newly opened
  folders until changed; a relaunch starting at 1×; every clip starting already at the selected
  speed with no 1× flash and no extra wait; scrubs, track clicks, keyboard seeks, and loop restarts
  all keeping the selected speed; audio sounding natural at 0.25× and at 2×; speed keys doing
  nothing — and changing nothing — on an image page, a non-current page, and mid-paging-gesture;
  clicks on the speed control never toggling play/pause; rapid speed changes staying stall-free; and
  the media files byte-identical on disk after all of the above (this is a UI story — functional
  review is part of the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R14; R11, R13, R15, R17 context;
  R16; RNF-02 / RNF-04; non-goals)
- [docs/decisions.md](../../decisions.md) — D13 (transport semantics incl. speed), D19 (scoped
  access), D22 (feed paging; App-owned input path), D25 (playback sessions), D26 (loop contract),
  D27 (chrome-free rendering; the ratified overlay-bar surface), D28 (feed-key router; quiet no-op
  guard matrix), D32 (seek mechanism — "never changes rate", evolved here), D33 (demand-driven
  overlay bar), D34 (keyboard seek rows; repeat parity)
- [docs/specs/e3-s1-scrub-seek/spec.md](../e3-s1-scrub-seek/spec.md) — direct predecessor (S3 bar
  contract, amended by S3 here; S10 seek rate contract, evolved by S13/S14 here; S12 guard premise
  carried by S16; S15 position-restart asymmetry noted under S8; S16 read-only carried by S17; S17
  responsiveness share pattern carried by S18)
- [docs/specs/e3-s1-scrub-seek/design.md](../e3-s1-scrub-seek/design.md) — §13 (E3 handoff: speed
  grows rate members on the same handle and may extend the bar strip; the keyboard table has room
  for more rows)
- [docs/specs/e2-s3-basic-playback/spec.md](../e2-s3-basic-playback/spec.md) — playback contracts
  (S1/S2 auto-play and settle, S4 images, S5–S8 toggle/frozen frame, S9/S10 revisit restart, S11
  loop, S12/S13 read-only)
- [docs/specs/e2-s2-vertical-feed-window/spec.md](../e2-s2-vertical-feed-window/spec.md) —
  paging settle, chrome-free viewport, unavailable state
- [docs/architecture.md](../../architecture.md) — Feed feature layout; §4 dependency rule
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E3-S2) and the E2–E5 coverage note
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
