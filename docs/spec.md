# InstantPlayer — Product Spec (source of truth)

An instant viewer for a folder of videos and images on macOS — open it from Finder, flip through a vertical feed, act on what you just watched. Zero setup, no waiting.

> Product source of truth; overridden only by ADRs in [docs/decisions.md](decisions.md).

## Product outline

- **Target user and main job-to-be-done** — a Mac user reviewing folders of downloaded clips, screen recordings, camera dumps, and saved photos; for them "instant" matters twice: zero steps from folder to viewing (R1–R5), and no perceptible wait before a clip plays (R11).
- **Sources of media** — local folders only, entered via Finder "Open With" on a file in the folder, or drag & drop of a file or folder onto the app or an open window; no network streams, no camera imports, no in-app folder picker (→ Non-goals; R1–R4).
- **Minimum playback experience** — native-format videos and images in one vertical feed (R7–R8); auto-play on arrival (R11); play/pause, scrub, and speed (R12–R14); app-level volume and mute, persisted (R18–R20); loop at end, never auto-advance (R15); keyboard-first navigation (R9–R10); a list view with zip/move/reveal/trash (R27–R33).
- **Scope boundaries** — one opened folder at a time, read-only media handling, ephemeral grouping only; the eight non-goals below mark the rest of the boundary, referenced not restated (media-collection rules in R34–R36).

## Functional requirements

- Promoted verbatim from the approved v1 product spec — [E1-S1 · Product spec authoring, story spec](specs/e1-s1-product-spec/spec.md) — which remains the permanent derivation record (persona, user stories, interview provenance).

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

## Non-functional requirements

- **RNF-02 (performance — pillar):** "Instant" is the product promise. Playback must start with no perceptible wait on the happy path; the UI stays smooth (no main-thread stalls); launch is minimal. See the `swift-performance` skill. Per-story budgets are set in story designs.
- **RNF-04 (security — pillar):** user media and any credentials are handled as private data: Keychain for secrets, sandbox + security-scoped access for files, validated external input, ATS intact, no undocumented tracking. See the `swift-security` skill.

RNF-01 and RNF-03 are intentionally unassigned in v1; the two pillars (RNF-02/RNF-04, D5) are the complete NFR set.

## Non-goals

Out of scope for v1; each may become its own story later:

- **Network streams** — local files only.
- **Camera imports** — no device ingestion.
- **Persistent albums/tags** — selection is ephemeral; grouping beyond ad-hoc multi-select is future work.
- **In-app folder picker** — no File > Open dialog in v1; entry is Finder Open With and drag & drop only.
- **Subfolder recursion** — direct children of the opened folder only.
- **Exotic codec support** — anything macOS cannot play or display natively is ignored until a future story adds it.
- **File editing/export** — no trimming, re-encoding, conversion, or export; "edit" means playback manipulation only.
- **Localization** — English only for v1 (D6); String Catalogs if a market is defined.
