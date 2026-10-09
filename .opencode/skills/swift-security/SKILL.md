---
name: swift-security
description: Security requirements for InstantPlayer — data at rest, network, sandbox & permissions, privacy, file handling, secrets, dependencies; load when building or reviewing anything security-relevant (RNF-04)
---

# Swift/macOS security (pillar — RNF-04)

Native SwiftUI app on macOS. Goal: a hard target — no secrets leaked, no unvalidated input executed, no undocumented tracking. Requirements below are review-level; violations are blockers.

## 1. Data at rest

- Secrets, tokens, credentials → **Keychain** (via the system API or a thin wrapper). Never `UserDefaults`, never files in `Application Support`/`tmp`, never `@AppStorage` for sensitive values.
- `UserDefaults` is fine for preferences (last volume, window state) — it is a plist on disk, readable in backups.
- User-picked files stay where they are; re-access them through **security-scoped bookmarks** (persist the bookmark, resolve before use, stop accessing when done).

## 2. Network

- App Transport Security stays on: no blanket `NSAllowsArbitraryLoads`. If a media source genuinely requires plain HTTP, scope the exception per-domain in `Info.plist` and record an ADR.
- HTTPS only for any API traffic. Certificate/environment pinning is a design decision — record an ADR if introduced.
- Never build URLs by interpolating raw user input (open-redirect/parameter pollution); validate and encode components.

## 3. Sandbox, permissions & privacy

- Decide the App Sandbox posture deliberately: entitlements (`com.apple.security.*`) grant the minimum needed (user-selected files read-only vs read-write, network client/server). No entitlement "because it might be useful".
- Every permission that triggers a TCC prompt (camera, microphone, photos, accessibility) needs a user-facing reason and an `Info.plist` purpose string, requested in context.
- `PrivacyInfo.xcprivacy` privacy manifest: declare required-reason APIs (e.g. `UserDefaults`) and collected data honestly. No analytics/tracking SDKs without an ADR.
- Do not read identifiers or anything beyond what the feature needs.

## 4. Input & interop

- Anything that enters from outside the sandbox — files from Finder/open-with/drag & drop, URLs from deep links or custom URL schemes, values from the pasteboard — is untrusted input: validate type, size, and path before use. Path traversal (`../`) and scheme confusion are real vectors.
- Playing a file must never execute it: no `WKWebView` loading local arbitrary content, no dynamic code loading, no spawning processes from file content. Playback APIs only.
- Never trust file extensions; inspect content (UTType) where format matters.

## 5. Secrets & configuration

- No API keys or tokens in source, `Info.plist`, or xcconfigs that are committed. If a key is unavoidable, it lives in a gitignored xcconfig file with a documented example; record an ADR.
- Never log secrets, full file paths of user media, or user content. Use `os.Logger` with privacy redaction: `\(value, privacy: .private)`.

## 6. Dependencies

- New SPM packages require justification in the story design (supply-chain risk) and a pinned version (`from:`/`exact:` with a recorded decision).
- Keep third-party dependencies minimal; every addition increases audit surface.

## Review checklist

- [ ] Secrets in Keychain only; nothing sensitive in `UserDefaults`, logs, or committed files
- [ ] Security-scoped bookmarks for user files; sandbox entitlements minimal and deliberate
- [ ] ATS intact (no blanket exception); per-domain exceptions documented via ADR
- [ ] Purpose strings present for every TCC-prompting permission; privacy manifest current
- [ ] External input (files/URLs/pasteboard/drag & drop) validated before use; no path traversal
- [ ] No user content or secrets in logs (`privacy: .private` where needed)
- [ ] New dependencies justified and pinned
