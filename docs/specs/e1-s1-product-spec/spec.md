# E1-S1 · Product spec authoring — story spec

- **Story:** E1-S1 · Product spec authoring — E1 (Product foundation), `in progress` ([docs/backlog.md](../../backlog.md))
- **Branch:** `feat/e1-s1-product-spec`
- **Phase:** Specify. This artifact is the source of truth for the v1 requirements; promotion into [docs/spec.md](../../spec.md) is later task work in this story.
- **Objective:** replace the bootstrap skeleton's `[NEEDS CLARIFICATION]` placeholders (target user, sources of video, minimum playback experience, scope boundaries) with the real v1 scope, authored in EARS notation, so the project gains a true product source of truth and feature epics can be broken out below E1.
- **Scope boundaries:** WHAT/WHY only — no tech stack, no implementation details. This phase does not touch `docs/spec.md`, `docs/backlog.md`, or `docs/decisions.md`.
- **Inputs:** stakeholder vision + interview (twelve decisions, all final); the [docs/spec.md](../../spec.md) skeleton (RNF-02/RNF-04 wording preserved verbatim); D1 (macOS app), D5 (pillars), D6 (English everywhere) in [docs/decisions.md](../../decisions.md).

## Story context

`docs/spec.md` is still the bootstrap skeleton: its product outline is four placeholder questions and its functional-requirements section is empty. Until it is filled, the project has no real source of truth, and no feature epics can be broken out below E1.

The stakeholder's vision: a macOS app to view multiple videos from a folder in a Stories/TikTok-style vertical feed — like Finder/Preview for a folder's content, but restricted to images and videos, minimal and light, keeping full playback control, plus a list view to select, group, and operate (zip, move). Smooth macOS integration. This story turns that vision and the twelve interview decisions into the complete v1 requirement set.

## v1 user stories

Persona: a Mac user browsing a folder of video clips and images — downloaded clips, screen recordings, camera dumps, saved photos. "Instant" matters twice for them: zero steps from folder to viewing, and no perceptible wait before a clip plays.

1. As a Mac user with a folder of clips and images, I want to open it straight from Finder (Open With on any file in it) or by dragging a file or folder onto the app, so that viewing starts with zero setup.
2. As a viewer flipping through the folder, I want a single vertical feed where each video or image fills the window and I move with a scroll gesture or the arrow keys, so that reviewing a batch is as fast as scrolling.
3. As a viewer watching a clip, I want full playback control — play/pause, scrub, playback speed, app-level volume and mute from the keyboard — so that I can inspect footage precisely without leaving the feed.
4. As a viewer watching a clip to the end, I want it to loop in place, so that replaying never yanks me to the next item.
5. As a viewer tidying a folder, I want a list view with multi-select and zip / move / reveal / trash operations, so that I can act on what I just watched without opening another app.
6. As a viewer, I want the feed and list to track the folder live, so that what the app shows always matches what is actually in the folder.

## EARS requirements

Numbered continuously, grouped by capability area. RNF references point at the pillars in [docs/spec.md](../../spec.md), quoted unchanged at the end of this section.

### Entry (opening media)

R1: WHEN the user opens a supported media file with InstantPlayer from Finder ("Open With")
    THE SYSTEM SHALL present the feed for that file's containing folder, positioned at the opened file

R2: WHEN the user drops a supported media file onto the app icon or onto an open InstantPlayer window
    THE SYSTEM SHALL present the feed for that file's containing folder, positioned at the dropped file

R3: WHEN the user drops a folder onto the app icon or onto an open InstantPlayer window
    THE SYSTEM SHALL present the feed for that folder's media, positioned at the first item in the current ordering

R4: WHEN the user opens or drops a file that is not supported media
    THE SYSTEM SHALL derive its containing folder and present that folder's media, ignoring the unsupported file

R5: WHEN the app is launched with no media, or is given a file or folder containing no supported media
    THE SYSTEM SHALL present a drop-target welcome state and open no folder

R6: WHEN InstantPlayer accesses media files provided through Finder or drag & drop
    THE SYSTEM SHALL access them only through the access the user's action grants, within the macOS sandbox (RNF-04)

### Feed navigation

R7: WHEN a folder's media is presented
    THE SYSTEM SHALL show its videos and images together in one vertical feed

R8: WHEN an item is the current item in the feed
    THE SYSTEM SHALL display it filling the viewport, preserving its aspect ratio (letterboxing as needed)

R9: WHEN the user performs a scroll gesture on the feed
    THE SYSTEM SHALL page to the adjacent item in the gesture's direction

R10: WHEN the user presses the ↓ or ↑ arrow key
     THE SYSTEM SHALL advance to the next item or return to the previous item, when one exists

### Playback

R11: WHEN a video becomes the current item in the feed
     THE SYSTEM SHALL start playing it automatically, with no perceptible wait on the happy path (RNF-02)

R12: WHEN the current item is a video and the user invokes play or pause
     THE SYSTEM SHALL resume or pause its playback accordingly

R13: WHEN the user scrubs or otherwise seeks within the current video
     THE SYSTEM SHALL move its playback position to the indicated point

R14: WHEN the user selects a different playback speed
     THE SYSTEM SHALL apply it to the current video

R15: WHEN the current video reaches its end
     THE SYSTEM SHALL restart the same video from its beginning and shall not automatically advance to the next feed item

R16: WHEN the user browses the feed, plays or pauses, scrubs, changes speed or ordering, or switches views
     THE SYSTEM SHALL keep the interface smooth and responsive, with no stalls (RNF-02)

R17: WHEN any v1 feature is exercised
     THE SYSTEM SHALL never rewrite, re-encode, or otherwise modify the contents of the user's media files

### Volume

R18: WHEN the user raises or lowers the volume from the keyboard
     THE SYSTEM SHALL adjust the application's own playback volume for video audio (app-level, not the system-wide output volume)

R19: WHEN the user toggles mute
     THE SYSTEM SHALL silence or restore the app's video audio

R20: WHEN the app is relaunched
     THE SYSTEM SHALL restore the volume and mute state from the previous session

### Ordering

R21: WHEN a folder is opened
     THE SYSTEM SHALL present its media in the folder's own order, in both feed and list

R22: WHEN the user switches the ordering to filename or date-added
     THE SYSTEM SHALL re-order both the feed and the list accordingly — alphabetical by file name, or by the date each file was added to the folder

### Live sync

R23: WHEN a supported media file is added to the opened folder while the app is open
     THE SYSTEM SHALL show it in the feed and list, placed per the current ordering

R24: WHEN a file is removed or moved out of the opened folder
     THE SYSTEM SHALL remove it from the feed and list

R25: WHEN a file in the opened folder is renamed
     THE SYSTEM SHALL update its displayed name and reposition it per the current ordering

R26: WHEN the item being viewed is removed or moved out of the folder
     THE SYSTEM SHALL drop it from the feed and keep the user positioned on a neighboring item

### List view & operations

R27: WHEN the user opens the list view
     THE SYSTEM SHALL list every media item in the opened folder, showing each item's file name, per the current ordering

R28: WHEN the user selects one or more items in the list
     THE SYSTEM SHALL mark them as the current selection, and list operations shall act on that selection

R29: WHEN the user builds a multi-selection
     THE SYSTEM SHALL treat it as one ad-hoc group for the next operation and shall not persist groups or tags

R30: WHEN the user compresses the selection
     THE SYSTEM SHALL create a single zip archive containing the selected media files

R31: WHEN the user moves the selection
     THE SYSTEM SHALL move the selected files into a destination folder the user chooses

R32: WHEN the user reveals a selected item
     THE SYSTEM SHALL reveal it in Finder

R33: WHEN the user moves the selection to the Trash
     THE SYSTEM SHALL ask for confirmation and, only after the user confirms, move the selected files to the macOS Trash in a recoverable way

Zip, move, and trash relocate or package files; none rewrites file contents (R17). Their effect on the feed and list follows from live sync (R23–R26).

### Formats & filtering

R34: WHEN the app collects a folder's media
     THE SYSTEM SHALL include only the folder's direct children, not descending into subfolders

R35: WHEN the app decides which files are media
     THE SYSTEM SHALL include only files macOS can play or display natively out of the box (for example the MP4/MOV family of videos, and JPEG/PNG/HEIC family still images)

R36: WHEN the opened folder contains files that are not supported media
     THE SYSTEM SHALL exclude them from every view and function of the app

### Window

R37: WHEN the app is running
     THE SYSTEM SHALL show the feed and list in a single window the user can resize

R38: WHEN media is opened while a folder is already being viewed
     THE SYSTEM SHALL present the newly opened folder in that same window, replacing the previous one

R39: WHEN the user resizes the window
     THE SYSTEM SHALL keep the current item filling the viewport

R40: WHEN the user enters or leaves native macOS fullscreen
     THE SYSTEM SHALL keep displaying the current item filling the screen

### Non-functional pillars (unchanged)

The product-level NFRs carry over verbatim from [docs/spec.md](../../spec.md) — this story preserves their wording and references them; it does not weaken or renumber them:

- **RNF-02 (performance — pillar):** "Instant" is the product promise. Playback must start with no perceptible wait on the happy path; the UI stays smooth (no main-thread stalls); launch is minimal. See the `swift-performance` skill. Per-story budgets are set in story designs.
- **RNF-04 (security — pillar):** user media and any credentials are handled as private data: Keychain for secrets, sandbox + security-scoped access for files, validated external input, ATS intact, no undocumented tracking. See the `swift-security` skill.

## Non-goals / future

Out of scope for v1; each may become its own story later:

- **Network streams** — local files only.
- **Camera imports** — no device ingestion.
- **Persistent albums/tags** — selection is ephemeral; grouping beyond ad-hoc multi-select is future work.
- **In-app folder picker** — no File > Open dialog in v1; entry is Finder Open With and drag & drop only.
- **Subfolder recursion** — direct children of the opened folder only.
- **Exotic codec support** — anything macOS cannot play or display natively is ignored until a future story adds it.
- **File editing/export** — no trimming, re-encoding, conversion, or export; "edit" means playback manipulation only.
- **Localization** — English only for v1 (D6); String Catalogs if a market is defined.

## Story acceptance criteria

- [ ] This spec passes the stakeholder approval gate.
- [ ] [docs/spec.md](../../spec.md) is filled from this artifact: all four outline placeholders (target user, sources of video, minimum playback experience, scope boundaries) replaced by the content above, and the functional-requirements section carries R1–R40.
- [ ] No `[NEEDS CLARIFICATION]` marker remains anywhere in `docs/spec.md`; the RNF-02/RNF-04 pillar wording is preserved verbatim.
- [ ] Every one of the twelve stakeholder interview decisions is represented by at least one EARS requirement above.
- [ ] Each capability area (entry, feed navigation, playback, volume, ordering, live sync, list view & operations, formats & filtering, window) is coherent and small enough to break out as a feature epic below E1 in `docs/backlog.md`.
