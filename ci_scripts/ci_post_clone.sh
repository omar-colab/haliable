#!/bin/sh
# Xcode Cloud runs this right after cloning. Secrets.xcconfig is git-ignored, so the
# cloud machine never has it and the build stops at "Unable to open base configuration
# reference file". Write it from the workflow's environment variables instead.
# Set them in App Store Connect → Xcode Cloud → workflow → Environment (mark as Secret).
# Missing ones are left empty: the app still compiles, it just has no live backend.
set -eu
# An archive becomes a TestFlight build: never ship one without its keys.
if [ "${CI_XCODEBUILD_ACTION:-}" = archive ]; then
  for k in USDA_API_KEY SUPABASE_URL SUPABASE_PUBLISHABLE_KEY; do
    eval "[ -n \"\${$k:-}\" ]" || { echo "error: $k is not set for this archive"; exit 1; }
  done
fi
out="$CI_PRIMARY_REPOSITORY_PATH/Haliable/Config/Secrets.xcconfig"
# xcconfig treats // as a comment, so "https://x" must be written "https:/$()/x".
esc() { printf '%s' "$1" | sed 's#//#/$()/#g'; }
{
  echo "USDA_API_KEY = ${USDA_API_KEY:-}"
  echo "SUPABASE_URL = $(esc "${SUPABASE_URL:-}")"
  echo "SUPABASE_PUBLISHABLE_KEY = ${SUPABASE_PUBLISHABLE_KEY:-}"
  echo "SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY:-}"
  echo "HALIABLE_API_BASE = $(esc "${HALIABLE_API_BASE:-}")"
} > "$out"
echo "Wrote $(wc -l < "$out") keys to Secrets.xcconfig (values not printed)"
