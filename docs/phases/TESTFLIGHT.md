# Haliable → TestFlight plan (Oct 2026)

Source of truth for humans: Notion "Haliable — TestFlight Master Plan" (one page per phase).
This file is the copy Claude Code reads. Update HANDOFF.md, not this file, as work progresses.

## Goal
Haliable installs from TestFlight on Omar's iPhone, scans real products reliably, and interviewers
(Connect.AI, within a week of Oct 13, 2026) can install it via a public TestFlight link / QR code.
NOT an App Store release. Add zero new features before the interview.

## Decisions (Oct 13, 2026)
- Scope: everything — scan, 4 standards, citations, Store Atlas map, Sign in with Apple, photo review.
- Bundle ID: app.haliable.ios (tests: app.haliable.ios.tests / .uitests). Fallback com.omaromar.haliable.
- Minimum iOS: 18.0 (was 26.5).
- Fonts: replace RomieTrial-* and ErnestTrial-Regular (trial licenses) with SIL OFL fonts from google/fonts.
- Supabase: free plan; old project abumevloleevhoqxfnoe frozen → restore if possible, else new project.
  Use NEW keys (sb_publishable_ in app, sb_secret_ server-only, sent in `apikey` header only — never Bearer).
  Legacy anon/service_role keys are retired by end of 2026.
- Keep-alive: daily GitHub Action reading 1 row (free projects pause after 7 idle days).
- Store map: replace 5 invented seed stores (0002) with 10–15 REAL CT halal stores (0007), sourced from
  OpenStreetMap (ODbL, attribute) or store websites. Never invent stores. Omar spot-checks first.
- Waitlist (MailerLite via netlify/functions/subscribe.js): quick end-to-end check in Phase 6.
- No domain / custom email yet. Support + feedback email = Omar's Gmail.
- Apple Developer Program (Individual, $99): PAID Oct 13, 2026 — awaiting approval.

## Hard rules
- Never build to a physical device with app.haliable.ios under the free Personal Team.
- Don't add the Sign in with Apple entitlement until the paid team is active (Phase 3).
- Never print/commit secrets; never ask Omar to paste keys into chat.
- Upload requirement: Xcode 26+ / iOS 26 SDK (since Apr 28, 2026). Builds expire 90 days after upload.

## Phases
| # | Phase | Needs Apple approval |
|---|---|---|
| 0 | Enroll + reset: Xcode check, tests, commit leftovers, CLAUDE.md + HANDOFF.md | No |
| 1 | Ship-ready build: bundle ID, iOS 18, fonts, remove CodeScanner, pre-flight checks (simulator only) | No |
| 2 | Rebuild backend: bootstrap.sql, new keys, Netlify header fix, real CT stores, keep-alive | No |
| 3 | Apple sign-in: paid team, SIWA capability, App ID + .p8 key, Supabase Apple provider, Netlify env, device test | Yes |
| 4 | First TestFlight build: App Store Connect record, Xcode upload, internal testing, fastlane beta | Yes |
| 5 | Public link: Test Information, external group, Beta App Review, QR code, site button | Yes |
| 6 | Demo-proof: 6 demo barcodes tested, QA checklist, 3-minute demo script, backup video, waitlist | No |
| 7 | Interview day + upkeep (90-day build expiry, keep-alive, FinGuard unblocked) | — |

The exact prompt for each phase lives on its Notion phase page. Omar pastes one phase per session.

## Fallback if Apple approval is late
Install from Xcode to Omar's phone with the free Personal Team using the OLD bundle ID omar.Haliable
(no SIWA entitlement; photo review runs in local mock mode) + a 90-second screen recording.
