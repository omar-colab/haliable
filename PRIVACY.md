# Haliable — Privacy Policy

**Draft / stub — review with legal counsel before publishing.**
_Last updated: 2026-06-11_

Haliable ("we", "us") builds a halal barcode scanner and community store map. This
policy explains what the app does and does not collect. Plain language, no dark
patterns — that's the whole point of the product.

## The short version

- **Scanning is on-device.** When you scan or type a barcode, we look it up against
  the anonymous **Open Food Facts** and **USDA FoodData Central** databases. We send
  only the barcode — never your name, account, or location — and the lookups are not
  tied to your identity.
- **Your scan history lives on your device.** It is stored locally (SwiftData) and is
  not uploaded. You can clear it any time in **Settings → Data & Privacy → Clear Scan
  History**, or export it in **Export My Data**.
- **An account is optional.** You can scan, browse, and use the map without signing in.

## What we collect, and when

### 1. Anonymous product lookups (always)
The barcode you scan is sent to Open Food Facts / USDA to retrieve product and
ingredient data. These requests are anonymous and contain no personal identifiers.

### 2. Account data (only if you sign in)
Signing in with **Sign in with Apple** is required only to **submit a manual review**
or **add a store** to the map. If you sign in, we store:
- a user identifier from Apple, and
- the email Apple provides (which may be a private relay address).

We use this solely to associate your submissions with your account and return your
review verdicts to you. We do not sell it or use it for advertising.

### 3. Manual-review submissions (only if you send one)
If you request a manual halal review, the **photos** and **notes** you submit are
uploaded to our backend so a reviewer can respond. You control whether to send them.

### 4. Location (only if you allow it)
If you grant location access, your approximate location is used **on-device** to center
the "Find Halal" map and search nearby. It is not stored on our servers or shared.

## What we do **not** do
- We do not track you across apps or websites.
- We do not sell or rent your personal data.
- We do not store your scan history on our servers.
- We do not require an account to scan.

## Your choices
- **Clear scan history:** Settings → Data & Privacy → Clear Scan History.
- **Export your data:** Settings → Data & Privacy → Export My Data.
- **Delete your account:** Settings → Account → Delete Account. This requests permanent
  deletion of your account and any server-side review data.
  _(Implementation note: the server-side deletion endpoint is pending — see the app's
  Settings TODO list. This must be live before public release.)_
- **Location:** revoke any time in iOS Settings.

## Third-party data sources
- **Open Food Facts** — product database, used under the Open Database License (ODbL).
- **USDA FoodData Central** — U.S. public-domain nutrition data.
- **Sign in with Apple** — authentication (see Apple's privacy policy).
- **Supabase** — backend for accounts and manual-review submissions (only used once you
  sign in / submit).

## A note on halal verdicts
Halal rulings reference IFANCA, ISNA, and AMJA guidance and are provided for
informational purposes. Always verify independently before relying on them. When a
source cannot be confirmed, Haliable shows **"Questionable"** rather than guessing.

## Children
Haliable is not directed at children under 13 and does not knowingly collect their data.

## Changes
We'll update this page and the "Last updated" date when this policy changes.

## Contact
Questions? Email **omarmontasir876@gmail.com**.
