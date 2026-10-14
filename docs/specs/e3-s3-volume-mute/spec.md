# E3-S3 · Volume & mute — Story Spec

## Story context

- **Why this story, why now.** E3's playback-controls epic closes here ("inspect footage precisely
  without leaving the feed", [docs/backlog.md](../../backlog.md)). E3-S1 landed scrub & seek and
  E3-S2 landed speed; this story lands the product spec's final playback member — product R18–R20,
  app-level volume and mute, persisted — which D14 named from the start ("volume belongs to the
  app's own playback … with keyboard operation and persistence"). Reviewing folders of mixed-sound
  clips currently means either disturbing the system output level or reaching for per-clip controls
  that do not exist; this story gives the app its own audio state, keyboard-first, remembered across
  relaunch. It also lands v1's **first persisted preference** (D14 sanctions exactly this one).
  E3-S1's and E3-S2's non-goal "Volume & mute (E3-S3) — product R18–R20" is landed here and
  nowhere else.
- **What "volume & mute" means end to end.** (Settled interview answers 1–5, bound — no
  re-litigation.) **⌘↑ / ⌘↓** step the volume and **`M`** toggles mute — a deliberate narrowing of
  the feed-key router's ⌘-pass-through with exactly these two exception rows (⌥/⌃ combos still pass
  through). The overlay control bar gains a **volume slider and a mute button** — the bar grows from
  E3-S2's six elements to eight. The step is **5% per step on a 0–100% scale** (20 steps), clamping
  at 0% and 100% with no wrap. **Adjusting the volume while muted unmutes** (macOS-style): mute is
  a flag, the level is remembered unchanged by muting, and unmuting restores that level; the level
  and the mute flag are persisted separately. Volume and mute are **app-level session state** —
  the input takes effect anywhere a feed is open.
- **Applicability is deliberately unlike the transport guard matrix (settled answer 5, stated
  plainly).** E3-S1 S12 and E3-S2 S16 guard seek and speed to the **settled current video** —
  non-current pages, mid-gesture pages, image pages, and unavailable items take no such input.
  **Volume/mute input deliberately does not follow that premise:** while a feed is open it takes
  effect wherever the user is — on an image page, on a non-current page, mid-paging gesture
  included — because the state is app-level (D14), not per-item. Only with **no feed open**
  (welcome state) do the keys pass through untouched. This is a recorded contract contrast, not an
  oversight; the guard matrix stands unchanged for seek and speed.
- **Amendment to the bar-contents contract (stated plainly).** E3-S1 S3 fixed the bar at four named
  elements; E3-S2 S3 amended it to six (adding the speed control and speed badge), following
  E3-S1's design §13 handoff — "the bar strip is the ratified home for future transport chrome,
  each addition its own spec decision" (D37 is the speed decision). **This story is that decision
  for volume:** the bar gains a volume slider and a mute button alongside the existing six —
  progress track, scrubber, elapsed label, duration label, speed control, speed badge — and nothing
  else. Everything else about the bar carries unchanged: demand-driven visibility on mouse
  movement, idle-hide, structural absence on image pages, and the whole strip's carve-out from the
  whole-page toggle target (so touching the volume controls never toggles play/pause).
- **Evolution of E2-S3's "audio unmuted" contract (stated plainly).** E2-S3 S3 — "auto-play plays a
  video with its audio unmuted", its settled answer 3, deferring app-level volume/mute to this
  story — evolves to **"audio at the app's volume/mute state"**. The first-launch defaults (100%,
  unmuted) make the observable behavior identical to E2-S3 S3 on a fresh install, so nothing there
  regresses. The honest reading added alongside it, analogous to E3-S2's start-at-speed S12: a
  video must **never blurt audio at a wrong level** — every start renders audio at the app's state
  from its first audible frame, and the restored state is in effect before the first frame of audio
  after a relaunch (S13).
- **Evolution of the no-persistence posture (stated plainly).** E3-S2 S9/S17 fixed "nothing is
  written anywhere — no persisted preference", and that stands for speed (E3-S2 S9 is a non-goal
  here). This story introduces v1's **first and only persisted preference** — the app's volume
  level and mute flag (product R20, D14) — so the read-only contract evolves from "nothing written"
  to "the only disk write is the app's own small preference record": media files, sidecars, and
  playback positions remain untouched (S16, S17). The storage mechanism is design-phase work under
  RNF-04's data-at-rest discipline (D14 defers the measures to the implementing story's design).
- **The feed-key router contract changes (stated plainly).** The frozen router table's standing
  modifier row — "⌘/⌥/⌃ combinations pass through, system shortcuts never robbed" (D28, D34, D38)
  — is deliberately narrowed by exactly two exception rows: **⌘↑ and ⌘↓** are claimed for volume
  stepping (settled answer 1). **`M`** claims a code that previously fell through to the default
  pass-through row (the D34/D38 recorded-contract-change pattern). ⌥/⌃ combinations and everything
  else still pass through. This is recorded as a visible contract change for the approval gate.
- **Product requirements carried.** product R18–R20 only (the assigned requirements,
  [docs/spec.md](../../spec.md)) — cited below as `product R#`, never renumbered or restated as new
  normative text. product R16 (cross-cutting responsiveness) applies as this story's share via S18,
  per the coverage note in [docs/backlog.md](../../backlog.md). product R17 (media files never
  rewritten) is an inherited no-regression contract carried via S17 — first-class in E2-S3, and
  deliberately scoped here to admit the one D14-sanctioned preference write. Story-scoped
  requirements (derivations and refinements) are numbered **S1…S18** in this file only.
- **Pillars.** Both pillars are engaged. **RNF-02 (performance):** steps, slider drags, the mute
  toggle, and the application of restored state must be instant and stall-free (S18), and no start
  may gain a wait or an audible wrong-level beat on account of the restored state (S13); numeric
  budgets are this story's design-phase output, which loads the `swift-performance` skill per the
  pillar rule (D5). **RNF-04 (security):** this story lands the app's first persisted preference,
  so storage discipline is now in scope — the small preference record is the only write, kept under
  RNF-04's data-at-rest rules with the concrete measures left to design (D14); volume/mute input is
  otherwise a **read** of the already-open security-scoped session (D19) with no new access paths
  and no writes to anything media-adjacent (S16, S17); the design loads the `swift-security` skill.
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE NOT affected.** Same decision and same
  reasoning as E3-S1's and E3-S2's: with no media open, the launch-visible behavior is unchanged —
  the welcome state and its launch cost are exactly as E2-S1/E2-S2 left them — and this story's
  entire surface (the bar's volume slider and mute button, the ⌘↑/⌘↓ and `M` keys) exists only
  once media is open, which the UI tests cannot reach: entry remains host-driven (Open With and
  drag & drop), the standing caveat E2-S1 through E3-S2 recorded. The router passes the keys
  through untouched with no feed, so even the launch-visible key behavior is unchanged. The
  UI-test-covered flows are launch flows, and they are untouched, so the converge run keeps the
  default gate scope with **no `--uitests` obligation** for this story
  ([docs/development.md](../../development.md) §3). Honest caveat, in the predecessors' form: even
  a `--uitests` run could not exercise volume/mute (no media is open in the launch tests), so the
  behavior is verified by unit tests — the router rows including the ⌘-exception, the step policy
  with clamping and hold-to-repeat, unmute-on-adjust, the mute-flag/level semantics, the persistence
  contract (defaults, fallback, separate level/flag), and guard/no-op behavior — plus stakeholder
  functional review.
- **Inherited contracts and how each interaction composes (E2-S1–E3-S2).** Volume and mute are
  properties of the **app session**, not of any item (settled answer 5) — the contrast with
  E3-S1 S12/E3-S2 S16's settled-current-video premise is recorded above and in S9. E3-S2's bar
  contract stands, amended only as stated above (its S3): the speed control, speed badge, and their
  hit-test island are untouched. E3-S2's speed semantics stand untouched — no seek or loop resets
  the speed (its S13/S14), and its S9 no-speed-persistence stands (S16). E3-S1's seek semantics and
  its strip carve-out (its S11) stand unchanged and extend to the new controls by the same rule.
  E2-S3's auto-play (S1), settle-only start (S2), toggle and frozen-frame semantics (S5–S8),
  paging-away stops / revisit restarts (S9/S10), loop (S11, product R15, D26), and unavailable-state
  contract (S14/S15) are untouched; only its S3 is evolved as stated above. The keyboard path
  follows the established App-owned input precedent (D22's consequence, D28's feed-key router,
  D34/D38's frozen-table row pattern) — input delivery is design detail; this spec states only the
  visible contract.
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md) (Feed feature),
  on top of E3-S2's playback and bar. Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a user reviewing clips with sound, I want ⌘↑ and ⌘↓ to step the app's volume so
  that I adjust loudness without touching the system output level or reaching for the mouse.
- **US2** · As a user in a quiet room, I want `M` to mute instantly — and to come back to exactly
  the level I was at, so that a phone call costs me one keystroke.
- **US3** · As a user with the control bar open, I want a volume slider and a mute button right
  there with the transport controls, so that the pointer can do what the keyboard does.
- **US4** · As a user who set my level yesterday, I want it remembered across relaunch — level and
  mute separately — so that I never re-adjust on every session.
- **US5** · As a user flipping through a mixed feed, I want volume and mute to be app-level and
  always live — even mid-page or on an image — so that there is no fiddly per-page audio state.
- **US6** · As a user startled by loud clips, I want a video never to blurt audio at the wrong
  level — the restored state is in effect from the very first frame of sound.
- **US7** · As a user reviewing my own media, I want volume settings to leave my files untouched —
  one small app preference record and nothing else — so that I can trust the app with my media.

## Story requirements (EARS)

Numbering is story-local: **S1…S18** for this story only. Product requirements are cited as
`product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that
merely anchor product text cite it; requirements that refine or derive add a short derivation note.

### Volume level & keyboard stepping (product R18 — settled answers 1, 3)

- **S1:** WHEN the user presses ⌘↑ or ⌘↓ while a feed is open
  THE SYSTEM SHALL step the application's playback volume 5% up or 5% down on a 0–100% scale
  (product R18; settled answers 1, 3)

*Derivation (S1):* product R18's anchor ("raise or lower the volume from the keyboard"), with the
invocations and step fixed by settled answers 1 and 3: **⌘↑ / ⌘↓**, **5% per step**, a **0–100%
scale** (20 steps from end to end). The modifier policy is the recorded contract change in Story
context: these are the router's **only** ⌘-exception rows — ⌥/⌃ combinations still pass through —
and, per the established row style (D38), ⇧ alone does not modify (⇧⌘↑ steps like ⌘↑). The
condition is "while a feed is open", not "while the settled current item is a video" — the
applicability contrast of settled answer 5 is S9. "Application's playback volume" is app-level
audio state (product R18: "app-level, not the system-wide output volume" — D14); nothing here
touches the system output level. Boundary behavior is S3; hold-to-repeat is S2; the slider surface
is S4.

- **S2:** WHEN the user holds ⌘↑ or ⌘↓ down
  THE SYSTEM SHALL repeat the 5% step (S1) for as long as the key auto-repeats — the same
  hold-to-repeat behavior as the ↑/↓ paging keys, the ←/→ seek keys, and the `[`/`]` speed keys

*Derivation (S2):* recorded as a reading of the settled rules, not as an interview answer — the
D22/D34/D38 repeat parity is the established stepping-input contract and nothing in the settled
answers departs from it; repeated steps near a bound clamp (S3). The stakeholder can veto this
reading at the approval gate.

- **S3:** WHEN a step would move the volume below 0% or above 100%
  THE SYSTEM SHALL remain at 0% or 100% respectively — the scale has ends and never wraps
  (settled answer 3)

*Derivation (S3):* settled answer 3 states clamping at 0% and 100% with no wrap outright; repeated
held steps near a bound clamp idempotently.

- **S4:** WHEN the user drags the volume slider on the overlay control bar
  THE SYSTEM SHALL set the application's playback volume to the indicated level on the 0–100% scale
  (product R18; settled answer 2)

*Derivation (S4):* settled answer 2's "volume slider" — the pointer surface over the same single
level the keyboard steps (the scale of answer 3). The slider's granularity (continuous or snapped)
and its placement on the strip are UI detail, design-phase output. A slider drag while muted is a
volume adjustment and unmutes (S8). *Recorded reading (strip carve-out):* a click or drag on the
slider never toggles play/pause — E3-S1 S11's carve-out extends to the new controls (the whole
strip stays excluded from the whole-page toggle target, per Story context). The stakeholder can
veto this reading at the approval gate.

### Mute (product R19 — settled answers 1, 2, 4)

- **S5:** WHEN the user presses the `M` key while a feed is open
  THE SYSTEM SHALL toggle mute — silence the application's video audio when unmuted, restore it
  when muted (product R19; settled answer 1)

*Derivation (S5):* product R19's anchor ("toggles mute"), invocation fixed by settled answer 1.
The key is claimed from the router's default pass-through row (the recorded contract change in
Story context). The modifier policy follows the established rows (D28, D34, D38): ⌘/⌥/⌃
combinations pass through (⌘M — system minimize — is never robbed), and ⇧ alone does not modify
(⇧M toggles like M). Hold behavior is recorded under S7's derivation (a held `M` is consumed and
ignored). The condition is "while a feed is open" (S9's applicability). The mute button is the
second invocation (S6); the flag semantics are S7.

- **S6:** WHEN the user clicks the mute button on the overlay control bar
  THE SYSTEM SHALL toggle mute exactly as `M` does (product R19; settled answer 2)

*Derivation (S6):* settled answer 2's "mute button" — the pointer surface over the same single
mute toggle; the two invocations share one state and one contract (S5, S7). The button's rendering
of the current mute state (as the slider renders the level) is presentation detail of the
model-driven bar pattern, design-phase output. *Recorded reading (strip carve-out):* a click on the
mute button never toggles play/pause — the same E3-S1 S11 carve-out as S4's note; the stakeholder
can veto this reading at the approval gate.

- **S7:** WHEN mute is toggled
  THE SYSTEM SHALL treat mute as a flag over the remembered level: muting silences the app's video
  audio without changing the volume level, and unmuting restores that level (settled answer 4)

*Derivation (S7):* settled answer 4's first half — "mute is a flag, the level is remembered
unchanged by muting; unmuting restores that level". Muting at 50% and unmuting returns to 50%, not
to 100% and not to 0%. *Recorded reading:* a held `M` is consumed and ignored after the first
press — never flapping mute on auto-repeat (the D28 space-parity rule: repeats of a toggle are
consumed and ignored). The stakeholder can veto this reading at the approval gate.

- **S8:** WHEN the user adjusts the volume while muted — by a ⌘↑/⌘↓ step or by dragging the slider
  THE SYSTEM SHALL unmute, applying the adjustment (settled answer 4)

*Derivation (S8):* settled answer 4's "adjusting the volume while muted unmutes (macOS-style)" —
the user's evident intent is to hear, so the mute flag clears and the level follows the adjustment.
*Recorded reading:* a step at a bound (⌘↑ at 100%, ⌘↓ at 0%) still counts as an adjustment and
unmutes even though the level cannot move — the macOS behavior and the intent reading; the
stakeholder can veto this reading at the approval gate.

### Applicability (settled answer 5 — deliberately unlike the transport guard matrix)

- **S9:** WHEN a feed is open and the user sends volume or mute input (⌘↑, ⌘↓, `M`, or the bar's
  volume controls) — whatever the current state of the feed is: a video or an image page, a
  non-current page, or a page while a paging gesture is in flight
  THE SYSTEM SHALL change the app-level volume/mute state accordingly, consuming the input quietly
  with no sound, no error, and never a beep (product R18, R19; settled answer 5)

*Derivation (S9):* settled answer 5 — "input takes effect anywhere a feed is open (including image
pages, non-current pages, mid-paging gestures), unlike the transport guard matrix". Image pages and
non-current pages have no audio to affect, but the app-level state (D14) still carries, so the
input is not a no-op there — this is the plain contrast with E3-S1 S12/E3-S2 S16 recorded in Story
context. The neutral unavailable state (E2-S3 S14/S15) and playback failure are unaffected: the
state changes like anywhere else and no failure semantics are touched. The consumption rule is the
recorded reading — with an open feed the rows are always consumed and quiet, never beep (D28's
lesson applied to input policy), and toggling/stepping changes only app audio state, never the
system output volume (product R18; D14).

- **S10:** WHEN no feed is open (the welcome state) and the user presses ⌘↑, ⌘↓, or `M`
  THE SYSTEM SHALL pass the keys through untouched — they are not consumed and change nothing

*Derivation (S10):* settled answer 5's second half ("with no feed open (welcome), the keys pass
through untouched") — the router's established `.passThrough` with no feed (D28, D34, D38), so
system behavior outside the app's feed context is never robbed and no quiet-consumption question
arises. This is also why the UI-test mandate above finds the launch-visible behavior unchanged.

### Applying the state (recorded reading; E3-S2 S10/S11 analog)

- **S11:** WHEN the user adjusts the volume or toggles mute while a video is playing
  THE SYSTEM SHALL apply it immediately to the running audio, with no restart and no change of the
  playback position

*Derivation (S11):* recorded as a reading of the settled rules — the E3-S2 S10 analog for audio:
the change is a level/mute change only; the video keeps playing from the same frame, now louder,
quieter, or silent. The stakeholder can veto this reading at the approval gate.

- **S12:** WHEN the user adjusts the volume or toggles mute while a video is paused
  THE SYSTEM SHALL remember the state and make it audible when playback resumes

*Derivation (S12):* the E3-S2 S11 analog — the frozen frame is unchanged (E2-S3 S8's pause
contract stands) and the resume is the first audible moment of the new state. The same path covers
the resume after a scrub drag (E3-S1 S8) and after a seek (E3-S1 S10). Recorded as a reading; the
stakeholder can veto it at the approval gate.

### Audio at the app's state on every start (E2-S3 S3, evolved)

- **S13:** WHEN a video starts playing — auto-play on arrival (E2-S3 S1), the restart on revisit
  (E2-S3 S10), or the loop restart at its end (E2-S3 S11) — including the first video after a
  relaunch
  THE SYSTEM SHALL produce its audio at the app's volume/mute state from its first audible frame —
  no momentary audio at any other level or mute state (E2-S3 S3, evolved)

*Derivation (S13):* the plain evolution recorded in Story context — E2-S3 S3's "audio unmuted"
reads as "audio at the app's volume/mute state", and the first-launch defaults (S15) make the fresh
install's observable behavior identical to E2-S3 S3. The honest reading added alongside it, the
E3-S2 S12 start-at-speed analog: a video must never blurt audio at a wrong level before the state
applies — the state is part of "ready to play", not a follow-up adjustment. On relaunch this makes
the restored state (S14) effective **before the first frame of audio** of the first clip — the
recorded R20 contract. R11's no-perceptible-wait promise is untouched and not re-claimed (S18).

### State persistence (product R20 — settled answer 4 + recorded R20 contract)

- **S14:** WHEN the app is relaunched
  THE SYSTEM SHALL restore the volume level and the mute state from the previous session — the two
  persisted as separate pieces of state (product R20; settled answer 4)

*Derivation (S14):* product R20's anchor ("restore the volume and mute state from the previous
session"), with settled answer 4's "persist level and mute flag separately": a muted session at 30%
relaunches muted at 30%, and unmuting after the relaunch yields 30% — the level is never collapsed
into the flag. The storage mechanism (where and how the small record lives) is design-phase output
under RNF-04 (D14 defers the measures). Timing is S13's; defaults and fallback are S15's.

- **S15:** WHEN the app runs for the first time, or the stored volume/mute state is missing or
  invalid
  THE SYSTEM SHALL use the defaults: volume 100%, unmuted

*Derivation (S15):* recorded as a reading of the settled rules and product R20 — the recorded R20
contract ("first launch defaults 100% / unmuted; missing or invalid stored state falls back to
defaults"): defaults are chosen so the fresh-install behavior is exactly E2-S3 S3's, and a corrupt
or unreadable record degrades to defaults rather than to a wrong level or an error. The stakeholder
can veto this reading at the approval gate.

- **S16:** WHEN the app persists volume/mute state
  THE SYSTEM SHALL persist exactly the volume level and the mute flag and nothing else — no speed
  preference (E3-S2 S9 stands), no playback or seek positions, no per-video state

*Derivation (S16):* recorded as a reading of the settled rules — the recorded R20 contract ("nothing
else is persisted") closes the scope of v1's one preference: E3-S2 S9's no-speed-persistence
carries unchanged (speed still starts at 1× after relaunch), positions remain unpersisted (E3-S1
S15/S16), and per-video volume is a non-goal. The state is app-level and session-spanning, one
record (settled answers 4 and 5).

### Read-only media (product R17 — inherited no-regression contract, scoped)

- **S17:** WHEN the user adjusts the volume or toggles mute
  THE SYSTEM SHALL modify nothing of the user's media — no rewrite of any media file, no sidecar or
  derived file, no persisted playback or seek positions — and the only disk write shall be the
  app's own small volume/mute preference record (product R17; E2-S3 S12/S13, E3-S1 S16, E3-S2 S17
  evolved)

*Derivation (S17):* product R17 is E2-S3's first-class requirement and an inherited no-regression
contract here — it forbids rewriting media files and is untouched by a preference record that never
touches media. The scope statement is the recorded R17 reading, stated plainly because this story
is where the posture evolves: the one D14-sanctioned write (v1's only persisted preference, S14)
is a small app-level record whose mechanism design must keep under RNF-04's data-at-rest discipline;
everything media-adjacent stays read-only through the already-open security-scoped session (D19 —
no new access paths, the session is not re-derived). E3-S2 S17's "nothing written" continues to
hold for speed.

### Responsiveness (product R16 — this story's share)

- **S18:** WHEN the user steps the volume, drags the slider, or toggles mute
  THE SYSTEM SHALL apply it instantly and keep the interface smooth and responsive — no stalls and
  no beachballing (product R16, RNF-02)

*Note (S18):* product R16 is deliberately not assigned to any single story
([docs/backlog.md](../../backlog.md) coverage note) — S18 states this story's share of the
responsiveness budget: the key steps (S1, S2), slider drags (S4), the mute toggle (S5, S6), and
the application of restored state before the first audio (S13) all happen without stalling the
interface. Numeric budgets are set in this story's design (RNF-02), which loads the
`swift-performance` skill.

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in
[docs/spec.md](../../spec.md) apply unchanged):

- **Speed persistence** — explicitly not this story (E3-S2 S9 stands): relaunch still starts at 1×
  and S16 persists only the volume level and mute flag. A persisted speed, if ever wanted, is its
  own future decision.
- **System-wide output volume control** — never (D14): the app adjusts its own playback volume
  only; the hardware/system output volume remains the user's control (product R18's own boundary).
- **Per-video volume** — the state is app-level and one (settled answer 5, S16); no per-item or
  per-folder levels, no keyed store.
- **Hardware volume keys / Now Playing interception** — the system's media keys and the Now Playing
  integration are not claimed; only the bar controls and the ⌘↑/⌘↓/`M` rows of S1, S5 are claimed.
- **Volume/mute chrome beyond the bar additions** — the bar is now the six E3-S2 elements plus the
  volume slider and mute button (S4, S6); hover thumbnails, chapter markers, buffered ranges, a
  floating HUD, on-video volume gestures, and any other transport chrome remain unclaimed.
- **The deferred control-bar polish follow-ups** — the progress-bar redesign and the speed-menu
  labeling notes from the E3-S2 functional review are unscheduled follow-ups
  ([docs/backlog.md](../../backlog.md) Follow-ups), not this story's work.
- **Feed/seek/speed semantics beyond the stated analogies** — paging, seek, speed, toggle, and loop
  contracts stand as written in E2-S2, E2-S3, E3-S1, and E3-S2; this story changes only what Story
  context states (E2-S3 S3 evolved; the bar extended; the router's ⌘ row narrowed).
- **Image volume semantics** — images have no audio (S9 covers their carrying the app-level state);
  their display contract is unchanged (E2-S2's chrome-free viewport).
- **Auto-advance** — foreclosed by product R15: at the end the same video restarts; feed
  advancement is always user-driven.
- **Ordering** (E4-S1) — product R21–R22; **live folder sync** (E4-S2) — product R23–R26;
  **list view & operations** (E5-S1, E5-S2) — product R27–R33.
- **Feed navigation & window behavior** — unchanged from E2-S2 (its S4–S11); this story adds audio
  state under the app session and alters no paging, ordering, or window semantics.
- **Network** — excluded from v1 entirely (D9); the preference record is written locally.

## Acceptance criteria

Product-requirement coverage map — the three product requirements assigned to this story (product
R18–R20 of [docs/backlog.md](../../backlog.md)) map to verifiable story outcomes; product R16 is
carried as a cross-cutting share via S18 and product R17 as an inherited no-regression contract via
S17 — neither is claimed as this story's own:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R18 (raise/lower the app's playback volume from the keyboard) | S1 (⌘↑/⌘↓, 5% steps), S2 (hold-to-repeat), S3 (clamping at 0%/100%, no wrap), S4 (slider surface), S9/S10 (applicability and pass-through), S11/S12 (immediate while playing, remembered while paused) | unit tests (router rows incl. the ⌘-exception; step policy, clamping, hold-to-repeat; slider set-level; applicability/no-op behavior; state application) + functional review (stepping both directions, clamps, slider, system volume untouched) |
| R19 (toggling mute silences or restores the app's video audio) | S5 (`M` toggle), S6 (mute button), S7 (flag semantics — level remembered, restored on unmute; held `M` ignored), S8 (unmute-on-adjust), S9/S11/S12 (applicability and application) | unit tests (mute toggle both invocations, flag/level separation, unmute-on-adjust incl. the clamp edge, repeat-ignored) + functional review (mute/unmute restores the exact level; adjust-while-muted unmutes; immediate on play, audible on resume) |
| R20 (restore volume and mute state on relaunch) | S13 (state in effect from the first audible frame; restored state before first audio after relaunch), S14 (level and flag restored, persisted separately), S15 (first-launch defaults 100%/unmuted; missing/invalid falls back), S16 (nothing else persisted) | unit tests (persistence contract: round-trip of level and flag separately, defaults, invalid-state fallback, nothing-else-persisted) + functional review (relaunch restores both independently; fresh/cleared state starts 100% unmuted; no wrong-level blurt) |
| R16 (smooth & responsive) — cross-cutting share via S18, not claimed | S18 — steps, slider drags, mute toggles, and restored-state application instant and stall-free; S13 — no added wait at any start | validator performance review (RNF-02; numeric budgets from this story's design) + functional review (rapid steps and drags stay fluid) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S17 — the only disk write is the app's own small preference record (D14-sanctioned); media, sidecars, and positions untouched; no new access paths (D19) | validator security review (the one write path and its RNF-04 discipline; session not re-derived) + functional review (files byte-identical on disk; only the app's preference record is new) |

- [x] Every product requirement assigned to this story maps to at least one story requirement; no
  other product requirement is claimed here (product R16 appears only as the shared responsiveness
  note S18; product R17 appears only as the inherited no-regression contract S17).
- [x] The contract changes are stated plainly in Story context: E2-S3 S3's "audio unmuted" is
  evolved to "audio at the app's volume/mute state" with the no-blurt reading (S13); the bar is
  deliberately extended from six to eight elements (S4, S6); the router's ⌘-pass-through is
  deliberately narrowed by exactly two rows and `M` is claimed (S1, S5); applicability deliberately
  departs from the transport guard matrix (S9); and the no-persistence posture admits exactly one
  preference record (S16, S17) while speed persistence stays out.
- [x] Volume/mute semantics are explicit and testable: both keyboard invocations and both bar
  controls (S1, S4, S5, S6), the 5% step and the 0–100% scale (S1), hold-to-repeat (S2), clamping
  without wrap (S3), mute-as-flag with level restoration (S7), unmute-on-adjust (S8), app-level
  applicability anywhere a feed is open and pass-through with none (S9, S10), immediate application
  while playing and remembered application while paused (S11, S12), start-at-state with no
  wrong-level blurt (S13), independent restoration of level and flag (S14), defaults and fallback
  (S15), and the bounded persistence scope (S16).
- [x] The one persisted preference is a reviewable contract: exactly the level and the flag (S16);
  the only disk write (S17); the RNF-04 data-at-rest measures are design-phase output (D14).
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json
  <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run keeps the default gate
  scope (UI-test mandate decision in Story context: flows are not affected).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: ⌘↑/⌘↓
  stepping the volume 5% per press with hold-to-repeat and clamping at 0% and 100% without wrap;
  `M` toggling mute and a held `M` doing nothing after the first press; unmuting restoring exactly
  the pre-mute level while muting leaves the level unchanged; adjusting the volume while muted —
  by key or slider — unmuting (including a step at a bound); the bar showing the volume slider and
  mute button alongside the six existing elements, with the slider setting the level and the button
  toggling mute; clicks and drags on those controls never toggling play/pause; adjustments taking
  effect immediately on a playing video with no restart and no position change, and being audible
  on resume when made while paused; the keys and controls taking effect on an image page, a
  non-current page, and mid-paging-gesture; ⌘↑/⌘↓/`M` passing through untouched at the welcome
  state and ⌥/⌃ combinations passing through everywhere; the system output volume never changing;
  a relaunch restoring level and mute independently and a fresh or cleared state starting at 100%
  unmuted; no clip ever starting with a wrong-level audio blurt (auto-play, revisit, loop, and the
  first clip after relaunch); rapid steps and slider drags staying stall-free; and the media files
  byte-identical on disk after all of the above, with the app's preference record the only new
  on-disk artifact (this is a UI story — functional review is part of the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R18–R20; R16, R17 context;
  RNF-02 / RNF-04; non-goals)
- [docs/decisions.md](../../decisions.md) — D13 (transport semantics), D14 (volume: app-level,
  keyboard-driven, persisted — this story's mandate), D19 (scoped access), D22 (feed paging; App-owned
  input path; repeat parity), D25 (playback sessions), D26 (loop contract), D27 (chrome-free
  rendering; the ratified overlay-bar surface), D28 (feed-key router; quiet no-op guard matrix),
  D33 (demand-driven overlay bar), D34 (keyboard seek rows; the recorded-contract-change pattern),
  D37 (speed surface; the bar-contents amendment pattern this story follows), D38 (speed rows;
  modifier policy)
- [docs/specs/e3-s2-playback-speed/spec.md](../e3-s2-playback-speed/spec.md) — direct predecessor
  (S3 bar-contents amendment, extended by S4/S6 here; S9/S17 no-persistence, evolved by S16/S17
  here; S10/S11 application analogs carried by S11/S12; S16 guard premise deliberately not carried
  — S9 here; S18 responsiveness-share pattern carried by S18)
- [docs/specs/e3-s1-scrub-seek/spec.md](../e3-s1-scrub-seek/spec.md) — bar contract (S3's four
  elements, demand-driven visibility; S11 strip carve-out, extended to the new controls by the
  recorded readings under S4/S6 here; S12 guard premise contrasted by S9; S17 responsiveness-share pattern)
- [docs/specs/e3-s1-scrub-seek/design.md](../e3-s1-scrub-seek/design.md) — §13 (E3 handoff: the bar
  strip is the ratified home for future transport chrome — "E3-S3 grows volume/mute members and
  lands v1's first persisted preference")
- [docs/specs/e2-s3-basic-playback/spec.md](../e2-s3-basic-playback/spec.md) — S3 ("audio
  unmuted"), evolved plainly here by S13; S1/S2 auto-play and settle, S5–S8 toggle/frozen frame,
  S9/S10 revisit restart, S11 loop, S12/S13 read-only, S14/S15 unavailable-state contract
- [docs/specs/e2-s2-vertical-feed-window/spec.md](../e2-s2-vertical-feed-window/spec.md) —
  paging settle and current-item premise (the contrast S9 draws), chrome-free viewport, unavailable
  state
- [docs/architecture.md](../../architecture.md) — Feed feature layout; §4 dependency rule
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E3-S3) and the E2–E5 coverage note;
  Follow-ups (the deferred control-bar polish notes)
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
