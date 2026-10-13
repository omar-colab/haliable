# HANDOFF — Haliable → TestFlight

Last updated: **Oct 13, 2026** (Phase 0 complete)
Plan: `docs/phases/TESTFLIGHT.md` · Rules for AI: `CLAUDE.md`

## Where we are

**Phase 0 (enroll + reset) — DONE.** Baseline verified, leftover work committed, repo rules
written down.

| Check | Result |
|---|---|
| Xcode | **27.0** (27A266a) — clears the Xcode 26+ / iOS 26 SDK upload rule |
| Simulators | iPhone 17 Pro / 17 Pro Max / 17 / 17e / Air on iOS 26.5; iPhone 18 Pro / 18 Pro Max / 17 / 17e / Air on iOS 27.0 |
| Test suite | **PASS** — all 134 test methods green on iPhone 17 Pro (iOS 26.5), `CODE_SIGNING_ALLOWED=NO`, exit 0. `NoTodoGuardTests` green. No failures to diagnose. |
| `build/` ever committed? | **No** — `git log --all -- build` is empty, nothing tracked |
| `Secrets.xcconfig` ever committed? | **No** — only `Secrets.example.xcconfig` is tracked |
| `graphify-out/` | now git-ignored |

Branch `main`, pushed. Working tree clean.

## What's next — Phase 1 (ship-ready build, simulator only)

1. Bundle IDs → `app.haliable.ios` / `.tests` / `.uitests`; fastlane Appfile + netlify
   `.env.example` follow.
2. `IPHONEOS_DEPLOYMENT_TARGET` 26.5 → **18.0** on all six build configs, then fix whatever
   the compiler flags as iOS-19+ API with `if #available` — no features removed.
3. Swap the trial fonts (see below).
4. Remove the CodeScanner SPM dependency.
5. Version 1.0 / build 1; verify `fastlane increment_build_number`.
6. Pre-flight pass/fail list.
7. Tests green + Release build for `generic/platform=iOS`.

Then Phase 2 (backend rebuild) — does **not** need Apple approval, so it's the right thing
to do while waiting.

## Things that could block TestFlight

| Blocker | Status |
|---|---|
| **Apple Developer Program approval** | Paid Oct 13, 2026. Nothing in Phases 3–5 can start until it lands. Phases 1, 2 and 6 don't need it. |
| **Trial font licenses** | `RomieTrial-{Light,Regular,Medium}.otf` and `ErnestTrial-Regular.otf` are evaluation-only and **cannot ship**. Being replaced in Phase 1. |
| **Supabase project frozen** | Old project `abumevloleevhoqxfnoe` is paused (free plan, 7 idle days). Phase 2 restores or recreates it with the new `sb_publishable_`/`sb_secret_` key format. |
| **Seeded fake stores** | Migration 0002 seeds 5 invented CT stores. Must be replaced with real OSM-sourced stores (migration 0007) before anyone sees the map. |
| **90-day build expiry** | A TestFlight build dies 90 days after upload. Don't upload the demo build too early. |

## Open questions for Omar

- Nothing blocking right now. Phase 1 questions (font choice, `if #available` fallbacks) are
  being decided with safe defaults and logged below.

## Decisions made while Omar was away

### Oct 13, 2026 — Phase 0
- **Two commits, not one.** The leftover app work + plan + `.gitignore` went in one commit;
  `CLAUDE.md` + `HANDOFF.md` in a second. Keeps the "commit as-is" snapshot clean and separate
  from new docs.
- **Test destination = iPhone 17 Pro, iOS 26.5.** It was already booted and is a real device
  family; iOS 27.0 sims exist but 26.5 is closer to what a tester's phone runs.
- **Did not touch the `ITSAppUsesNonExemptEncryption` move.** Committed exactly as found —
  the build-settings version (`INFOPLIST_KEY_…` in both Debug and Release) is the correct
  place for it, and `Info.plist` no longer duplicates it.
