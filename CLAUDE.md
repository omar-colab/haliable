# CLAUDE.md — rules for any AI working in this repo

Haliable is a native SwiftUI iOS app that scans a product barcode and tells you whether it
is halal under four schools of thought, with a scholarly citation behind every judgement.
Omar is a solo junior developer. Explain things in plain language.

## Stack — locked, do not swap

| Layer | Choice |
|---|---|
| UI | SwiftUI, `@Observable` (not `ObservableObject`), `NavigationStack` |
| Persistence | SwiftData |
| Backend | Supabase via `supabase-swift` 2.x (SPM) |
| Serverless | Netlify functions in `netlify/functions/` |
| Marketing site | `site/` (static, Netlify) |
| Release | fastlane in `fastlane/` |

No new dependencies without being asked. The barcode scanner is native AVFoundation
(`Haliable/Services/Scanner/BarcodeScannerView.swift`) — don't reintroduce a scanner package.

The Xcode project uses **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`).
A file dropped into `Haliable/` is in the target automatically — you do not edit the `pbxproj`
to add resources. You *do* edit it for build settings.

## Hard rules

1. **Never print, log, echo, or commit a secret.** Real keys live only in
   `Haliable/Config/Secrets.xcconfig` (git-ignored) and in Netlify/Supabase dashboards.
   Never ask Omar to paste a key into chat. If you need one, tell him which dashboard
   field to fill and stop.
2. **Never hand-edit `Haliable/Resources/Citations.json`.** It is generated and
   human-approved through the citation pipeline. Changing it by hand silently breaks the
   clearance gate.
3. **Report, don't rule.** Never change a halal grade, a verdict, or a matrix cell without
   a citation from a Tier 1 or Tier 2 source. The app's job is to report what scholars
   said, not to decide. When a cell has no citation it stays `pending`/`needsReview` —
   that is correct behavior, not a bug to paper over.
4. **Worst-case verdict safety.** A product rolls up to the *worst* grade among its
   ingredients. Never "optimize" that into an average or a best case.
5. **`NoTodoGuardTests` must stay green.** No `TODO`/`FIXME` in fiqh source files.
6. **Run the full test suite before every commit.** Green, or you don't commit.
7. **No new features before the Connect.AI interview.** See `docs/phases/TESTFLIGHT.md`.

## Device / signing rules (until the paid Apple team is approved)

- **Simulator only.** Do not build to a physical device with `app.haliable.ios`.
- Do **not** add the Sign in with Apple capability or entitlement yet — registering the
  bundle ID under the free Personal Team would bind it to the wrong team.

## Commands

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# full test suite
xcodebuild test -scheme Haliable \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO

# release build check (no signing, no device)
xcodebuild -scheme Haliable -configuration Release \
  -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

SourceKit/index warnings in the editor are usually index lag, not real errors — trust
`xcodebuild`.

## Ending a session — all four, every time

1. Tests green (including `NoTodoGuardTests`).
2. Commit.
3. Push.
4. `HANDOFF.md` updated: where we are, what's next, what needs Omar.

If you made a judgement call while Omar was away, write it under
"Decisions made while Omar was away" in `HANDOFF.md` — don't leave it only in chat.
