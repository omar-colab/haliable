#!/usr/bin/env bash
# Does a sb_publishable_ key still work when a client ALSO sends it on
# Authorization: Bearer?
#
# Why this matters: supabase-swift 2.48 sets BOTH headers from the single key it's
# constructed with:
#     "Authorization": "Bearer \(supabaseKey)",
#     "Apikey": supabaseKey,
# When a user is signed in it overwrites Authorization with their real access token,
# so that path is fine. Signed OUT — which is how the Store Atlas is read, and how a
# demo starts — the publishable key goes out on Bearer. Supabase's migration guide
# says these keys aren't JWTs and Bearer makes the platform try to parse one; it
# currently accepts them there only as a transitional compatibility measure.
#
# This script answers it empirically instead of guessing.
#
#   ./supabase/check-publishable-key.sh
#
# Reads SUPABASE_URL and SUPABASE_ANON_KEY out of the git-ignored
# Haliable/Config/Secrets.xcconfig. Nothing is printed but HTTP status codes —
# the key value never reaches stdout.
set -euo pipefail
cd "$(dirname "$0")/.."

CFG=Haliable/Config/Secrets.xcconfig
[ -f "$CFG" ] || { echo "missing $CFG" >&2; exit 2; }

val() {  # read an xcconfig key, undoing the /$()/ escape used for //
  sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$CFG" | head -1 | sed 's|/\$()/|//|g' | tr -d '\r'
}
URL=$(val SUPABASE_URL)
KEY=$(val SUPABASE_ANON_KEY)

[ -n "$URL" ] && [ -n "$KEY" ] || { echo "SUPABASE_URL or SUPABASE_ANON_KEY not set in $CFG" >&2; exit 2; }

case "$KEY" in
  sb_publishable_*) KIND="new publishable key" ;;
  eyJ*)             KIND="legacy anon JWT" ;;
  *)                KIND="unrecognised format" ;;
esac
echo "Project: ${URL}"
echo "Key:     ${KIND}"
echo

probe() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$@" \
    "${URL}/rest/v1/stores?select=id&limit=1"
}

A=$(probe -H "apikey: ${KEY}")
echo "A  apikey only .......................... HTTP ${A}   <- the correct way"

B=$(probe -H "apikey: ${KEY}" -H "Authorization: Bearer ${KEY}")
echo "B  apikey + Authorization: Bearer ....... HTTP ${B}   <- what supabase-swift sends signed out"

echo
if [ "$A" = "200" ] && [ "$B" = "200" ]; then
  echo "PASS — both work. The app can use the publishable key as-is."
  echo "Note this rests on Supabase's transitional Bearer compatibility, so re-run"
  echo "this after any supabase-swift or platform upgrade."
elif [ "$A" = "200" ] && [ "$B" != "200" ]; then
  echo "PROBLEM — the key works alone but NOT the way supabase-swift sends it."
  echo "The signed-out Store Atlas would break. Options:"
  echo "  1. Keep the legacy anon JWT in the app (works on Bearer; retired end of 2026)"
  echo "     and use sb_secret_ only server-side."
  echo "  2. Strip the Authorization header in a custom session/fetch handler passed"
  echo "     via SupabaseClientOptions.global."
  exit 1
else
  echo "Neither variant returned 200 — check the project is restored and the URL/key are right."
  exit 1
fi
