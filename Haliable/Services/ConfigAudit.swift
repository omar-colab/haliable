//
//  ConfigAudit.swift
//  Haliable
//
//  A loud-at-startup (DEBUG only) report of which backend secrets are wired, so a
//  missing key surfaces immediately in the console instead of silently degrading
//  a halal verdict. We deliberately do NOT crash the app in release: a missing
//  USDA key only disables the USDA *fallback* tier (Open Food Facts still works),
//  and a missing Supabase config only disables contribute features (browsing and
//  scanning stay fully functional). The right response is a clear warning, not a
//  hard boot failure that would punish users for an unset optional key.
//

import Foundation

enum ConfigAudit {

    /// Logs the configuration state once at launch (DEBUG builds only).
    static func preflight() {
        #if DEBUG
        var lines = ["── Haliable config preflight ─────────────────────────"]

        if USDAFoodDataService.isConfigured {
            lines.append("✅ USDA_API_KEY set — USDA lookup tier enabled.")
        } else {
            lines.append("⚠️ USDA_API_KEY MISSING — USDA tier disabled (Open Food Facts still works).")
            lines.append("   Add it to Haliable/Config/Secrets.xcconfig.")
            lines.append("   Free key: https://fdc.nal.usda.gov/api-key-signup.html")
        }

        if SupabaseConfig.isConfigured {
            lines.append("✅ SUPABASE_URL + SUPABASE_ANON_KEY set — backend enabled.")
        } else {
            lines.append("⚠️ SUPABASE not configured — sign-in / reviews / store submit run in local mock mode.")
            lines.append("   Set SUPABASE_URL and SUPABASE_ANON_KEY in Secrets.xcconfig.")
        }

        lines.append("──────────────────────────────────────────────────────")
        print(lines.joined(separator: "\n"))
        #endif
    }
}
