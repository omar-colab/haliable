# HANDOFF — Haliable → TestFlight

Last updated: **Oct 13, 2026** (Phases 0, 1 and 2 complete)
Plan: `docs/phases/TESTFLIGHT.md` · Rules for AI: `CLAUDE.md`

## Where we are

**Phase 0 (enroll + reset) — DONE.**
**Phase 1 (ship-ready build, simulator only) — DONE.**

The app now builds Release for a real device target, carries shippable fonts, and
passes every pre-flight check. Nothing is left that needs Apple approval before
Phase 3.

### Phase 0 results

| Check | Result |
|---|---|
| Xcode | **27.0** (27A266a) — clears the Xcode 26+ / iOS 26 SDK upload rule |
| Simulators | iPhone 17 Pro / 17 Pro Max / 17 / 17e / Air on iOS 26.5; iPhone 18 Pro / 18 Pro Max / 17 / 17e / Air on iOS 27.0 |
| Test suite (baseline) | **PASS** — 134 tests green, exit 0, no failures to diagnose |
| `build/` ever committed? | **No** — `git log --all -- build` empty, nothing tracked |
| `Secrets.xcconfig` ever committed? | **No** — only `Secrets.example.xcconfig` is tracked |
| `graphify-out/` | now git-ignored |

### Phase 1 results

| # | Item | Result |
|---|---|---|
| 1 | Bundle IDs | `app.haliable.ios` / `.tests` / `.uitests`. `fastlane/Appfile` and `netlify/functions/.env.example` (`APPLE_CLIENT_ID`) updated. Only `omar.Haliable` left is the deliberate fallback note in `TESTFLIGHT.md`. |
| 2 | Deployment target | 26.5 → **18.0** on all six configs. **Zero `if #available` fallbacks needed** — nothing in the app used post-iOS-18 API. Verified by a clean Release compile, not just an incremental one. |
| 3 | Fonts | Trial fonts replaced with OFL (details below), before/after screenshots in `docs/screenshots/font-swap/`. |
| 4 | CodeScanner | Removed. Confirmed first that no Swift file imports it — the scanner has been native AVFoundation (`BarcodeScannerView`) for a while; that file's own comment says it "replaces the previous third-party CodeScanner package". Dropped from `project.pbxproj` and `Package.resolved`. |
| 5 | Versions | `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`. `increment_build_number` **did not work** and is now fixed — see "Things I fixed". |
| 6 | Pre-flight | All pass — table below. |
| 7 | Tests + Release build | **135 tests green** (incl. `NoTodoGuardTests`). `xcodebuild -configuration Release -destination 'generic/platform=iOS'` → **BUILD SUCCEEDED**. |

### Pre-flight (checked against the actual Release bundle, not the source)

| Check | Result |
|---|---|
| `ITSAppUsesNonExemptEncryption` | ✅ `false` in the built `Info.plist` |
| `NSCameraUsageDescription` | ✅ present |
| `NSPhotoLibraryUsageDescription` | ✅ present |
| `NSLocationWhenInUseUsageDescription` | ✅ present |
| `PrivacyInfo.xcprivacy` in app target | ✅ present in the bundle |
| AppIcon 1024, no alpha | ✅ `AppIcon-1024.png` is 1024×1024, `hasAlpha: no`. The dark and tinted variants *do* have alpha — that is correct and required for iOS 18 icon variants, not a problem. |
| No trial / template / trademarked assets | ✅ Trial fonts deleted. Asset catalog is colour sets plus your own `HMark`/`LaunchMark` crescents — no third-party logos, no Xcode template leftovers. |
| Built bundle identity | `app.haliable.ios`, version 1.0 (1), `MinimumOSVersion 18.0` |

## The font swap

| Was (trial — could not ship) | Now (SIL OFL 1.1 — ships fine) |
|---|---|
| RomieTrial-Light / Regular / Medium | **Spectral** Light / Regular / Medium |
| ErnestTrial-Regular | **Instrument Serif Italic** |

Spectral was picked because it's the only strong editorial serif on google/fonts
that ships **real static Light/Regular/Medium files** — an exact 1:1 swap for
Romie's three cuts. Most of the closer-looking families (EB Garamond, Newsreader,
Cormorant) are variable-font-only now, which on iOS means extra Core Text work to
reach a non-default weight.

Instrument Serif has a **true italic face**, where Ernest was upright-only and was
being sheared synthetically. So two things changed with it: `.italic()` came off
the accent tokens, and `ObliqueText.obliqueness` now defaults to `0`. The knob is
still there if a future accent face needs it. Compare
`docs/screenshots/font-swap/before/` and `after/` — the look holds.

**Alternates, if you don't like these:**

- Instead of Spectral: **(1) Playfair Display** — already bundled in the repo, so
  zero new files; higher contrast, more fashion-magazine. **(2) Newsreader** — the
  closest in feel to Romie, but variable-only, so the Light/Medium weights need
  Core Text variation axes wired up first.
- Instead of Instrument Serif: **(1) Spectral Italic** — same family as the display
  serif, so more uniform but less of a distinct accent voice. **(2) EB Garamond
  Italic** — warmer, more calligraphic; variable-only file.

## Things I fixed that weren't on the list

Both were caught by the Release build — neither shows up in a simulator Debug build,
which is why they'd gone unnoticed.

1. **🚨 `Secrets.xcconfig` was being copied into the shipping app bundle.** The
   project uses file-system-synchronized groups, so everything under `Haliable/`
   gets bundled — including `Haliable/Config/Secrets.xcconfig`. Your USDA key would
   have shipped inside the IPA where anyone who unzips it can read it. Fixed with
   `EXCLUDED_SOURCE_FILE_NAMES = "*.xcconfig"` on every config; verified both
   xcconfig files are gone from the built `.app`.
   *Related, and working as intended:* `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `USDA_API_KEY` and `HALIABLE_API_BASE` are in the app's `Info.plist` by design —
   that's how the app reads them. Anything there is readable by anyone with the
   IPA, so only *publishable* keys may go in. The `sb_secret_` key must stay
   server-side, as the plan already says.
2. **The Release build didn't compile at all.** The `#Preview` blocks in
   `MyReviewsV2.swift` used the `#if DEBUG` preview fixtures without being guarded
   themselves. Wrapped them in `#if DEBUG`. (This came from the work-in-progress I
   committed as-is in Phase 0, so it was never Release-built before.)
3. **`fastlane increment_build_number` would have failed.** It wraps `agvtool`,
   which needs `VERSIONING_SYSTEM = "apple-generic"` — the project never set it.
   Added to all six configs and verified the bump works (1 → 2), then reset to 1.
   Without this, the `fastlane beta` lane in Phase 4 would have died on its first
   step.

## Phase 2 (rebuild backend) — DONE, applied live

Project `abumevloleevhoqxfnoe` restored and `ACTIVE_HEALTHY`.

| # | Item | State |
|---|---|---|
| 1 | Netlify `apikey` header fix | ✅ `svcHeaders()` sends `apikey` only; `getUser()`'s Authorization left alone (it carries the *user's* JWT). |
| 2 | `bootstrap.sql` | ✅ Generated by `supabase/build-bootstrap.sh`; includes 0007. |
| 3 | Real stores | ✅ `0007_real_stores` applied live — 5 UConn campus locations, the 5 invented demo stores deleted. |
| 4 | Keep-alive Action | ✅ Pushed. **Needs two repo secrets before it can run** (below). |
| 5 | New-format keys | ✅ `sb_publishable_` in `Secrets.xcconfig`; verified working. |
| 6 | Schema applied | ✅ 0001–0006 were preserved by the restore (all 4 RPCs, 5 policies). 0007 applied. |
| 7 | RLS proof | ✅ `rls_matrix.sql` passes all five invariants against the live database. |

### 🚨 The big find: supabase-swift was never linked

`supabase-swift` was declared in `project.pbxproj` as a package *reference*, but its
product was never linked to the app target — no `XCSwiftPackageProductDependency`,
nothing in `packageProductDependencies`, nothing in the Frameworks phase. So
`canImport(Supabase)` was **false**, every live-backend path compiled out, and
`StoreService` silently served its bundled mock seed.

**The Store Atlas, sign-in and photo reviews had never reached Supabase.** The build
was green the whole time, which is exactly why nobody caught it. It surfaced only
because the map kept showing invented stores after the real ones were in the database.

Fixing it surfaced a second thing: Swift 6's `MemberImportVisibility` means `import
Supabase` no longer re-exports Auth, so `import Auth` is now explicit in five files.
`AuthManager` had `#if canImport(Supabase)` blocks and **no import at all**.

**Lesson for later: a green build does not prove a dependency is linked.** If the live
backend ever looks suspiciously like sample data again, check
`nm`/`packageProductDependencies` before debugging the network.

### Still needs Omar

1. **🔑 Rotate the `sb_secret_` key.** It was pasted into a chat transcript. It bypasses
   RLS entirely. Supabase → Project Settings → API Keys → revoke and regenerate.
   Nothing uses it yet (no Netlify site), so rotating costs nothing.
2. **Two GitHub repo secrets**, or the keep-alive workflow fails on its first run:
   `gh secret set SUPABASE_URL` and `gh secret set SUPABASE_PUBLISHABLE_KEY`
   (both prompt with hidden input). Then run it once manually from the Actions tab.
3. **CrossRoads Cafe and Market Cafe** — UConn lists five cafes, only three are in
   OpenStreetMap. Street addresses would let me geocode and add the other two.

### Notes

- `supabase link` needs no database password; `supabase db query --linked` goes through
  the Management API on the CLI login session. `apply-migrations.sh` uses that.
- `check-publishable-key.sh` confirmed the publishable key works both with and without
  the `Authorization: Bearer` header supabase-swift adds when signed out. Re-run it after
  any supabase-swift or platform upgrade — Bearer support is transitional.
- `SupabaseConfig.functionsBase` still points at `haliable.netlify.app`, which does not
  exist. Only Sign in with Apple (Phase 3) uses it.
- Xcode 27 removed Simulator.app; the simulator UI is now **DeviceHub.app**.

## After Phase 2
## After Phase 2

## Things that could block TestFlight

| Blocker | Status |
|---|---|
| **Apple Developer Program approval** | Paid Oct 13, 2026. Phases 3–5 can't start until it lands. Phases 2 and 6 don't need it. |
| ~~Trial font licenses~~ | ✅ Resolved in Phase 1. |
| **Supabase project frozen** | Old project `abumevloleevhoqxfnoe` is paused (free plan, 7 idle days). Phase 2 restores or recreates it. |
| **Seeded fake stores** | Migration 0002 seeds 5 invented CT stores. Must be replaced with real OSM-sourced ones before anyone sees the map. |
| **90-day build expiry** | A TestFlight build dies 90 days after upload. Don't upload the demo build too early. |

## Open questions for Omar

1. **Do you like the new fonts?** Compare `docs/screenshots/font-swap/before/` with
   `after/`. If not, two alternates per font are listed above and the swap is a
   four-line change in `Haliable/Theme/Typography.swift` plus the `UIAppFonts` list.
2. **Rotate the USDA key?** It shipped into local Release builds only — nothing was
   uploaded anywhere and nothing was committed, so the exposure is almost certainly
   zero. Rotating is cheap (it's a free key) if you'd rather be certain.
3. Nothing else is blocking. Phase 2 can start without you.

## Decisions made while Omar was away

### Oct 13, 2026 — Phase 0
- **Two commits, not one.** The leftover app work + plan + `.gitignore` in one;
  `CLAUDE.md` + `HANDOFF.md` in a second. Keeps the "commit as-is" snapshot clean.
- **Test destination = iPhone 17 Pro, iOS 26.5.** Already booted, and closer to what
  a tester's phone runs than the 27.0 sims.
- **Didn't touch the `ITSAppUsesNonExemptEncryption` move.** Committed as found — the
  build-settings version is the correct place and `Info.plist` no longer duplicates it.

### Oct 13, 2026 — Phase 1
- **Spectral + Instrument Serif** over the alternates, for the reasons above. The
  deciding factor was real static weight files vs. variable-only.
- **Turned off the synthetic italic shear** rather than leaving it at 0.2. Instrument
  Serif is already italic, so keeping the shear would have double-slanted it. Kept the
  `obliqueness` parameter rather than deleting the `ObliqueText` machinery — it still
  earns its place putting mixed serif+italic runs on one baseline.
- **Credited all five bundled fonts**, not just the two new ones. Playfair Display,
  Nunito and Yellowtail were already shipping with no attribution; adding them was one
  line each and closes a real licence gap.
- **Added the OFL licence texts to `docs/licenses/`** rather than into the app bundle.
  The repo redistributes the font binaries, so the licence has to travel with it
  (OFL §2); in-app credit is the Acknowledgements screen.
- **Verified `increment_build_number` via `agvtool` directly.** fastlane isn't
  installed on this machine and installing it wasn't worth it unattended — `agvtool`
  is what fastlane calls underneath and ships with Xcode, so it's a faithful check.
- **Extended `ScreenshotUITests` instead of writing a throwaway script** for the
  before/after shots. A verdict screenshot is something you'd want for the App Store
  page anyway, so it earns its keep. It drives the manual-barcode path (the camera
  can't scan in a simulator) and is best-effort: with no network it captures the error
  state rather than failing the suite.
- **Left `Haliable/Config/Secrets.xcconfig` on disk untouched.** Only excluded it from
  the bundle. Your key is where it was.
