# Haliable iOS — How to open & run in Xcode

This covers the Part 1 build: the scanner, the rules-engine "Questionable" fix,
the **photo manual-review** feature (Supabase), and the **Store Atlas scaffold**.

> The app **compiles and runs as-is** with no setup — it uses an in-memory mock
> for reviews and seeded sample data for the map. The steps below are only needed
> to turn on the **real** Supabase backend and device features.

---

## 1. Open the project

1. Double-click `Haliable.xcodeproj`.
2. The `Haliable/` group is a *file-system synchronized* folder, so every file
   added on disk (all the new ones) is already in the project — no manual adding.
3. Select the **Haliable** scheme and a target device.

## 2. Build & run the basics (no backend needed)

- **Simulator:** the camera doesn't exist there, so use the **"Or enter a
  barcode"** field on the Scan tab (try `0049000028911`). Verdicts, the rules
  engine, history (SwiftData), and the map (seeded pins) all work.
- **Physical device (recommended):** real barcode scanning + photo capture.
  You need a free Apple ID set under *Xcode → Settings → Accounts*, and select
  your team under *Signing & Capabilities*.

## 3. Required Info.plist permission strings

Target **Haliable → Info** tab → add these rows (Xcode merges them into the
generated Info.plist):

| Key | Suggested value |
|---|---|
| Privacy - Camera Usage Description | "Haliable uses the camera to scan barcodes and photograph products for review." |
| Privacy - Photo Library Usage Description | "Attach product photos from your library for a manual halal review." |
| Privacy - Location When In Use Usage Description | "Show halal stores and restaurants near you." |

Without the camera string the app will crash when opening the scanner.

## 4. Turn on the real backend (optional, for the review feature)

### a. Add the Supabase Swift package
*File → Add Package Dependencies…* → `https://github.com/supabase/supabase-swift`
→ Up to Next Major **2.0.0** → add the **Supabase** product to the Haliable target.

> The code is guarded with `#if canImport(Supabase)`, so before you add the
> package it builds against the mock; after you add it, the live path activates.
> (Written against supabase-swift **2.x** — if your version's Storage/Auth call
> signatures differ, the two spots are flagged with comments in
> `ReviewStore.swift` / `AuthManager.swift`.)

### b. Add Sign in with Apple
*Signing & Capabilities → + Capability → Sign in with Apple.*

### c. Create `Secrets.xcconfig`
1. Copy `Haliable/Config/Secrets.example.xcconfig` → `Haliable/Config/Secrets.xcconfig`
   (it's git-ignored).
2. Fill in `SUPABASE_URL`, `SUPABASE_ANON_KEY` (Supabase → Project Settings → API),
   and your `USDA_API_KEY`.
3. Project → **Info → Configurations**: set *Based on Configuration File* to
   `Secrets` for Debug and Release.
4. Target → **Info** tab → add custom rows so the app can read them:
   `SUPABASE_URL = $(SUPABASE_URL)`, `SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY)`,
   `USDA_API_KEY = $(USDA_API_KEY)`, and (optional) `HALIABLE_API_BASE = $(HALIABLE_API_BASE)`.

### d. Set up the database
In Supabase → SQL Editor, paste and run **`supabase-setup.sql`** (repo root).
Then enable **Apple** under Authentication → Providers.

You're live: a signed-in user can submit photos → they land in Storage + the
`review_requests` table; you set the verdict (SQL snippet at the bottom of the
setup file) and it appears in **My Reviews**.

## 5. Notes & what's deferred

- **CodeScanner** package is no longer used (replaced by AVFoundation). You can
  remove it via *Package Dependencies* if you like — harmless if left.
- **Store Atlas backend** (Node/Express + Supabase/PostGIS) is **scaffolded
  client-side only**. `StoreService` serves seeded sample stores; every method
  has a `TODO(Atlas backend)` marking where the real API call goes. The model
  and method signatures already match the dossier's API contract.
- **Rules citations** in `rules-v1.json` are best-effort and should be verified
  against the actual IFANCA/ISNA/AMJA sources before you rely on them publicly.
- Push notifications for "your review is ready" are intentionally out of scope —
  status updates appear on pull-to-refresh.
