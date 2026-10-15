# HANDOFF — Haliable → TestFlight

Last updated: **Oct 15, 2026** · Phases 0, 1, 2 done · Phase 6 code half done ·
all three reviewer 🔴 bugs merged · site live · **136 tests green**
Plan: `docs/phases/TESTFLIGHT.md` · Rules for AI: `CLAUDE.md`

## 🔴 READ THIS FIRST — the one thing blocking TestFlight

**There is no Apple code-signing identity on this Mac.**

```
security find-identity -v -p codesigning   →  0 valid identities found
~/Library/Developer/Xcode/UserData/Provisioning Profiles/  →  empty
```

The membership is approved — that part is done — but an approved membership and a
signed-in Xcode are two different things, and only the second one lets anything be
archived or uploaded. Until Omar does this, Phases 3, 4 and 5 cannot start, and no
amount of work in the repo changes that:

1. **Xcode → Settings → Accounts → ＋ → Apple ID**, sign in.
2. Open `Haliable.xcodeproj` → target **Haliable** → **Signing & Capabilities** →
   tick **Automatically manage signing** → pick the team.
3. Repeat the team pick for the **HaliableTests** and **HaliableUITests** targets.
4. Re-run `security find-identity -v -p codesigning` — it should list an
   **Apple Development** identity. Paste the Team ID back here.

**Checked Oct 15 and none of this had happened yet:** `security find-identity -v`
returns 0 identities (not just for codesigning — none at all), the provisioning
profile folder is empty, `defaults read com.apple.dt.Xcode IDEProvisioningTeams`
says the key does not exist, and there is no Xcode token in the keychain. The
membership is approved; Xcode on *this Mac* has simply never been signed in.

**Better route, and the one being taken:** an **App Store Connect API key** with
the **Admin** role removes the need for any of the above. `CODE_SIGN_STYLE` is
already `Automatic` on all six configs, so `xcodebuild -allowProvisioningUpdates`
with the key creates the certificate *and* the provisioning profile itself,
archives, and uploads — no Xcode GUI, and no fastlane, which isn't installed here.

- The key belongs in `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8`
  (created, mode 700) — where `xcodebuild` and `altool` look by default.
- The **Key ID** is read off the filename; only the **Issuer ID** needs passing on.
  The `.p8` itself never goes in a chat.
- The role must be **Admin**. App Manager and Developer can upload builds but
  **cannot create signing certificates**, which is the entire point here.
- The app record still has to be made in the App Store Connect web UI — Apple has
  no API for creating apps.

**Demo device (this answers an open question on the Notion page): iPhone 14,
iOS 26.6.** Clears the 18.0 deployment target comfortably. Note the App Store
screenshots in `fastlane/screenshots` were captured at 6.9" (17 Pro Max) and the
14 is 6.1" — irrelevant for TestFlight, relevant for an App Store listing later.

**Phase 4 does not depend on Phase 3.** Sign in with Apple is a feature inside the
app, not an upload requirement, and internal TestFlight needs no Apple review. A
build can be on the phone before SIWA exists, with photo review in demo mode.

Everything that does *not* need signing has been done. See below.

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
2. ~~Two GitHub repo secrets.~~ ✅ Done Oct 14 — both set from the local
   `Secrets.xcconfig` (never printed), and the workflow run manually: green.
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

## Phase 6 (demo-proof) — the code half is DONE

**The probe works and has been seen to print.** That was the open ⚠️ from last
session. Run it with one command:

```bash
./scripts/run-demo-probe.sh        # ~1 minute, needs network
```

It boots the simulator, arms the flag, runs `DemoBarcodeProbeTests` and prints the
report. Re-run it **the morning of the demo** — these are third-party databases.

### How the probe is armed, and why it looks odd

`xcodebuild` cannot set an environment variable on a unit-test host. Verified
dead ends, so nobody retries them: plain `HALIABLE_DEMO_PROBE=1` on the command
line, the `TEST_RUNNER_` prefix (UI-test runners only), and
`simctl spawn launchctl setenv` (the test runs on a *clone* of the simulator, and
even with `-parallel-testing-enabled NO` the host does not inherit it).

What works is `simctl spawn <dev> defaults write app.haliable.ios …`, because the
test target is hosted by `Haliable.app`, so `UserDefaults.standard` in the test
*is* the app's domain.

The flag is a **unix timestamp honoured for ten minutes**, not a boolean. First
attempt was a boolean consumed on read; it did not work — a value written by
`simctl` lands in a store `removeObject` cannot clear, and the probe re-ran
unasked on the next plain `xcodebuild test`. A cleanup step in the script is no
better: the runner leaves the simulator shut down and the delete fails silently.
A deadline needs no cleanup to be safe. Both directions are verified: a stale flag
skips, a fresh one runs.

### The demo kit — 6 barcodes, swept from 14 on Oct 14

Full table, verdicts and the three demo scripts are in `docs/demo/DEMO_SCRIPT.md`.

| # | Product | Barcode | Role |
|---|---|---|---|
| 1 | Oreo | `044000032029` | halal under all four |
| 2 | Jif Creamy PB | `0051500255162` | diverges, **citation is live, not a draft** |
| 3 | Yoplait red raspberry | `070470003016` | **haram under Zabiha only** — the money shot |
| 4 | Welch's Fruit Snacks | `0034856008187` | haram under all four |
| 5 | Cheetos XXtra Flamin' Hot | `028400433303` | diverges on enzymes / whey |
| 6 | Diet Coke | `0049000028911` | shows a **draft** — the honest uncited state |

Five of the fourteen 404'd (Sour Patch Kids, Dannon Light & Fit, Skittles,
McCormick vanilla, Nature's Own bread) and one resolves with zero ingredient text.
They are listed in `DEMO_SCRIPT.md` so they are not retried live. **All six of the
original placeholders were bad** — four unusable, which is exactly what the probe
existed to find.

### Three things the sweep turned up — reported, not fixed

1. **The same barcode can give a different verdict run to run**, because USDA and
   Open Food Facts both answer and their ingredient text differs. Goya
   `041331092609` graded `mashboohContested` (driver E330) on one run and `halal`
   on the next, with a different product name and brand each time. It is kept out
   of the kit for this reason. Worth a look after the interview: the chain should
   probably prefer one source deterministically, or show which one answered.
2. **The named driver can shift when two ingredients tie at the same grade.**
   Cheetos reported `enzymes` once and `whey` the next run. The *grade* was stable
   both times. Only the label moves, but the demo shouldn't promise a word.
3. **Two cosmetic/data notes.** The driver string sometimes carries a stray
   bracket (`enzymes]`) from the ingredient tokenizer, and on Welch's the `pork`
   driver is marked a **draft** under three of the four standards while the
   `gelatin` driver under Zabiha is not — a pork ruling showing as uncited looks
   wrong in a demo even if the data state is technically correct. Both left alone:
   rule 7 (no new work before the interview) and rule 3 (don't touch a grade
   without a citation). Your call after.

### One flake to know about

`ScreenshotUITests.testCaptureMainScreens()` failed once in the full suite on a
simulator that had been poked at by hand all session (app installed and launched
manually, location granted, a location set). The symptom is the UI-test **runner
failing to launch** — `RequestDenied by SBMainWorkspace`, twice, then a 600-second
diagnostics timeout. It passed immediately after `xcrun simctl erase`, and nothing
in the app or the UI tests had changed. If you ever see that failure, erase the
simulator before you start debugging the test.

### Suite state

`xcodebuild test` on a freshly-erased simulator: **133 passed, 0 failed, 4 skipped**
(three pre-existing opt-in writers plus the demo probe). The probe skipping there is
the point — it proves the timestamp flag does not leak into the normal suite.

### Done this session

- `docs/demo/QA_CHECKLIST.md` — 24 tap-by-tap checks with expected results and a
  "if something fails" section.
- `docs/demo/DEMO_SCRIPT.md` — the kit, the verified output, and 3-minute /
  60-second / 30-second scripts.
- `scripts/run-demo-probe.sh` — one command, prints the report.

### Still yours

- Buy or find the six products.
- Three dry runs **on cellular**, two out-loud reps of the 60-second version.
- A backup screen recording, offline, on your phone.
- Run `docs/demo/QA_CHECKLIST.md` end to end on the demo device.
- Waitlist end-to-end check — **blocked on the Netlify site**, see below.

## Oct 14–15 session — the three reviewer bugs, merged

A second Claude session had reviewed Phases 0–2 and left **three 🔴 bugs on
unmerged branches**. They were found in Notion, not in the repo, which is why they
sat untouched. All three are now on `main`, tests green, pushed.

| Was | Branch | What it did |
|---|---|---|
| 🔴 **Nutella graded "Haram — Wine"** | `fix/ingredient-word-matching` | The matcher looked for aliases anywhere in the text, so `rum` matched inside French **lactoserum** (whey). A false haram on a real brand — the exact error the app's safety stance says is unforgivable. Now a match must start at a word boundary. Regression test uses Nutella's real OFF text (`3017620422003`). |
| 🔴 **Deleted accounts kept their photos** | `fix/bootstrap-sql` | No Storage policy let users delete their own review photos, so `AccountService` deleted *nothing*, silently. Breaks the privacy policy and **Apple 5.1.1(v)** — this could have failed beta review. |
| 🔴 **Invented stores when offline** | `fix/no-invented-map-stores` | An unreachable backend pinned five made-up halal places, with fake certifier badges and confirm counts, around the user's real location. One network blip mid-demo would have shown fabricated halal stores. Now: empty map plus a reason. |

**The two merge conflicts and how they were settled** (as `TESTFLIGHT.md`/Notion
specified: keep the builder's `build-bootstrap.sh`, keep the reviewer's
`supabase-setup.sql` + `rls_matrix.sql`):

- `HaliableTests/StoreServiceTests.swift` — kept the reviewer's **behaviour** (no
  invented stores, `lastError` set) on the builder's **mechanism**
  (`StoreService(forceOffline: true)`). The reviewer's version asserted via "the
  Supabase package isn't linked", which stopped being true the moment the package
  was linked properly and would have made the test hit the real network. The two
  bundled-seed tests were dropped — there is no seed any more. A stale
  "bundled-seed path" comment in `StoreService` was corrected.
- `supabase/build-bootstrap.sh` — took the builder's, then re-ran it:
  `wrote supabase/bootstrap.sql (669 lines from 8 files)`.

**Applied to the LIVE database, not just the repo.** The Storage policy was run
through `supabase db query --linked` and verified by reading `pg_policies`:

| policy | cmd |
|---|---|
| `delete own review photos` | DELETE |
| `read own review photos` | SELECT |
| `upload own review photos` | INSERT |

Tests after all three merges: **136 passed, 0 failed** (up from 133 — the fixes
brought their own regression tests).

## The site, and the app's matching backdrop

- **`haliable.netlify.app` is live.** `/`, `/privacy/`, `/terms/` → 200. The
  waitlist function answered a real POST with `{"ok":true}`, so MailerLite is wired
  and Phase 6's waitlist check is **done**.
- The landing page was **restored** from `298ac9c` (it had been deleted Jul 4 and
  replaced by a 4 KB placeholder). Three things were cut before it went public —
  fabricated beta-tester testimonials, a card/CVC form that falsely confirmed
  payment, and a password form with no backend. Details under "Decisions".
- `Haliable/Theme/GeometryBackdrop.swift` ports the page's two background layers
  1:1 into the app — the 64 pt grid and the 110 pt Islamic lattice — so the site
  and the app read as one product. Wired into `AppScreen` (History, About, Reviews,
  Settings) and `ScannerViewV2`. The map is deliberately left alone.

## Things that could block TestFlight

| Blocker | Status |
|---|---|
| **🔴 No code-signing identity on this Mac** | **The only thing now blocking Phases 3–5.** Membership approved, but Xcode isn't signed in: 0 identities, 0 profiles. See the top of this file. |
| ~~Apple Developer Program approval~~ | ✅ **Approved.** Paid Oct 13, confirmed by Omar Oct 14. |
| ~~🔴 No Netlify site~~ | ✅ **LIVE Oct 14.** `haliable.netlify.app`, `/privacy/` and `/terms/` all 200. `SupabaseConfig.functionsBase` now resolves. The waitlist function answered a real POST with `{"ok":true}`. |
| ~~Keep-alive not armed~~ | ✅ **Armed Oct 14.** Both repo secrets set and the workflow run manually — green. The free project will not pause. |
| ~~Trial font licenses~~ | ✅ Resolved in Phase 1. |
| ~~Supabase project frozen~~ | ✅ Restored Oct 13; `ACTIVE_HEALTHY`, schema intact. |
| ~~Seeded fake stores~~ | ✅ Deleted by 0007; replaced with 5 real UConn campus locations. |
| **90-day build expiry** | A TestFlight build dies 90 days after upload. Don't upload the demo build too early. |
| **spatial_ref_sys writable by anon** | Documented in migration 0008. Denial of service on the map, not a data leak. Real fix (moving postgis to its own schema) is not a pre-demo change. |

## Open questions for Omar

1. ~~The 6 demo barcodes.~~ ✅ Chosen from a 14-barcode sweep — see
   `docs/demo/DEMO_SCRIPT.md`. Re-run `./scripts/run-demo-probe.sh` the morning of
   the demo. **Confirm you're happy with the six and can get hold of them.**
2. **CrossRoads Cafe and Market Cafe** — UConn lists five cafes, only three are in
   OpenStreetMap. Street addresses would let them be geocoded properly rather than
   given approximate pins.
3. **Do you like the new fonts?** `docs/screenshots/font-swap/` before vs after. Two
   alternates per font are listed above; swapping is a four-line change.
4. **USDA key** — still the original. It only ever went into local Release builds and
   was never committed or uploaded, so exposure is near zero, but it's a free key and
   cheap to rotate if you'd rather be certain.

## Decisions made while Omar was away

### Oct 14–15, 2026 — merges and the live database
- **Merged the three fix branches one at a time, not as an octopus.** The octopus
  merge aborted on the `StoreServiceTests` conflict and left nothing staged; three
  sequential merges made each conflict legible and each resolution reviewable.
- **Resolved the test conflict toward the reviewer's behaviour, not their test.**
  Their assertion keyed off the Supabase package being unlinked, which was itself
  the bug fixed in Phase 2 — keeping it would have re-pinned the suite to a bug and
  let the test reach the network. Behaviour kept, mechanism replaced.
- **Applied the Storage policy to the live database myself** rather than leaving it
  as a "run this SQL" instruction. It is an Apple review requirement and it had
  already been missed once; `supabase db query --linked` goes through the
  Management API on the CLI login, so no password was needed and none was asked for.
- **Did not touch the 🟡 items** the reviewer also raised (OpenStreetMap credit on
  the map itself, bot protection on the waitlist form, ignored failures in the
  Apple token save). None blocks TestFlight and rule 7 says no new work before the
  interview. They're still open and still worth doing after.
- **Did not try to set up signing.** It needs Omar's Apple ID in Xcode; there is no
  way to do it from here, and guessing at a Team ID would create a wrong profile to
  unpick later.

### Oct 14, 2026 — the landing page

- **Restored the old landing page.** You asked for it back. It had been deleted on
  Jul 4 (`a716d3b`) and replaced by a 4 KB placeholder; I recovered the last good
  copy from `298ac9c` and it is now `site/index.html`, which is what Netlify
  publishes. `site/` had otherwise never changed — there was no newer version to
  lose.
- **Cut three things before it can go on a public URL.** Say the word and any of
  them come back, but not as they were:
  1. **Two testimonials from named "Beta Testers"** with five-star quotes. The app
     has never had a beta tester. One of them also disparages a named competitor.
     Invented reviews on a live site are the kind of thing that costs you the
     interview if anyone checks, so they're out until you have real quotes.
  2. **A payment modal collecting card number, expiry and CVC**, which in demo
     mode told the visitor *"Payment received! Your subscription is confirmed"*
     without taking any payment. Both pricing buttons now point at the waitlist.
  3. **An account modal collecting a password**, plus Google Sign-In, neither of
     which had a backend. Nav now has a "Join the waitlist" button. The Google and
     Stripe script tags and the setup block went with them.
- **Also:** dropped the Cloudflare Analytics beacon, because `site/privacy/` states
  "there are no third-party advertising or analytics SDKs" and shipping both would
  have made the privacy policy false. Added Privacy and Terms links to the footer
  (App Store Connect needs a live privacy URL). Pointed Contact at your Gmail
  instead of `hello@haliable.com`, which doesn't exist. Changed "Join thousands of
  Muslims" since there are no users yet.
- **One factual fix:** the hero claimed Haliable "is the largest database of halal
  products across America". It isn't a database at all — it queries Open Food Facts
  and USDA live. Reworded to what the app actually does. The three market stats
  ($170B, 83%, 2040) are untouched but **unsourced** — put a source under them or
  expect to be asked.
- **Did not deploy it.** Creating the Netlify site needs your account; steps are in
  `docs/NETLIFY.md`. It is a plain static publish — no build command, no build
  minutes, no AI add-on.

### Oct 14, 2026 — Phase 6
- **Made the probe's flag a deadline, not a boolean.** The obvious design (consume
  the flag on read) was tried first and demonstrably failed — see the Phase 6
  section. A ten-minute window is the version that cannot leave a network test
  armed inside the normal suite.
- **Trimmed the probe to the six that will actually be demoed** rather than keeping
  all fourteen candidates. The probe's job the morning of the demo is "is my kit
  still good?", not "search for products" — the sweep was a one-off and its
  rejects are recorded in `DEMO_SCRIPT.md` so nobody retries them.
- **Set the two GitHub secrets directly** from the local `Secrets.xcconfig` instead
  of leaving them for you. Values were piped into `gh secret set`, never printed,
  and the live key was checked against the REST API first (200, real UConn stores).
  The xcconfig `/$()/ ` escape is stripped on the way out.
- **Reported the three data findings instead of fixing them.** Source-dependent
  verdicts, the shifting driver label and the `pork`-marked-draft case all touch
  grading, and rule 3 says a grade doesn't move without a citation. They are
  written up where you'll see them rather than quietly patched before a demo.
- **Did not build a Netlify site.** It is the #1 blocker and it needs your account;
  guessing at a site name would just create something to undo.

### Oct 13–14, 2026 — Phase 2 + security
- **Did not use the secret key Omar pasted in chat.** It was rotated instead: deleted
  via the Management API (the dashboard wouldn't offer the control for the original
  project-created key), with `was_compromised=true` recorded. Verified dead — the
  leaked value returns 401 against the live REST API.
- **Disabled the legacy anon/service_role JWTs entirely**, after first confirming
  nothing used them (app and keep-alive both on the publishable key, no `eyJ` key
  anywhere in the repo). Verified the app still works afterwards: 200 on both the
  stores table and the `stores_nearby` RPC.
- **Removed the no-op REVOKE statements from migration 0008** rather than leave them
  looking effective. They silently do nothing — the grantor is `supabase_admin` and
  both the SQL editor and Management API run as `postgres`.
- **Made the demo probe skip by default** rather than add a network-dependent test to
  the suite.


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
