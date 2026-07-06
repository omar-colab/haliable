# App Privacy "nutrition label" — transcribe into App Store Connect

App Store Connect ▸ your app ▸ **App Privacy**. Confirmed against the on-device-scan
privacy story (June 26, 2026). Answer "Data Collection": **Yes, we collect data** (only
when the user signs in to contribute).

For each type below: **Collected? / Linked to identity? / Used for tracking? / Purpose.**
Nothing is used for tracking; no third-party ads or analytics SDKs.

| Data type (ASC category) | Collected | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| **Email Address** (Sign in with Apple) | Yes | Yes | No | App Functionality |
| **Name** (Sign in with Apple) | Yes | Yes | No | App Functionality |
| **Photos or Videos** (manual-review submissions) | Yes | Yes | No | App Functionality |
| **Coarse Location** (only when submitting a store) | Yes | Yes | No | App Functionality |
| **Other User Content** (store names / review notes) | Yes | Yes | No | App Functionality |

### Explicitly NOT collected (do not declare)
- **Barcode scans & scan history** — processed on-device; never sent to us. (The
  barcode number is sent anonymously to Open Food Facts / USDA for lookup, not
  retained by us and not linked to the user — so it is not "collected" by the app.)
- **Precise location** — the map uses device location locally; we don't store it.
- No identifiers for advertising, no usage analytics, no diagnostics SDKs.

### Notes for the reviewer / your records
- Account is optional: browsing + scanning need no sign-in.
- All collected data supports app functionality (community reviews + store map).
- Open Food Facts product data is shown under ODbL (attribution in-app under
  Settings ▸ Acknowledgements and in the privacy policy).
