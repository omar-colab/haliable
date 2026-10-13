#!/usr/bin/env bash
# Write Supabase credentials into the git-ignored Haliable/Config/Secrets.xcconfig
# WITHOUT the value ever appearing on screen, in your shell history, or in a chat
# transcript. The prompt is silent (read -s) and the file is written directly.
#
#   ./supabase/set-local-key.sh
#
# Press Enter at any prompt to leave that value unchanged.
set -euo pipefail
cd "$(dirname "$0")/.."

CFG=Haliable/Config/Secrets.xcconfig
[ -f "$CFG" ] || cp Haliable/Config/Secrets.example.xcconfig "$CFG"

# xcconfig treats // as a comment, so a URL must be written https:/$()/host
esc_url() { printf '%s' "$1" | sed 's|//|/$()/|g'; }

set_key() {  # set_key <KEY> <value>
  local k="$1" v="$2" tmp
  tmp=$(mktemp)
  # Replace the line if present, otherwise append. Value passed via awk -v so no
  # shell quoting games and nothing is echoed.
  awk -v k="$k" -v v="$v" '
    $0 ~ "^"k"[[:space:]]*=" { print k " = " v; found=1; next }
    { print }
    END { if (!found) print k " = " v }
  ' "$CFG" > "$tmp"
  mv "$tmp" "$CFG"
  chmod 600 "$CFG"
}

echo "Writing to $CFG (git-ignored, never committed)."
echo "Values are not echoed. Press Enter to skip any field."
echo

printf 'Supabase project URL (https://<ref>.supabase.co): '
read -r URL
if [ -n "$URL" ]; then set_key SUPABASE_URL "$(esc_url "$URL")"; echo "  ✓ SUPABASE_URL set"; fi

printf 'Supabase publishable key (sb_publishable_...): '
read -rs KEY; echo
if [ -n "$KEY" ]; then
  case "$KEY" in
    sb_publishable_*) echo "  ✓ new-format publishable key" ;;
    eyJ*)             echo "  ✓ legacy anon JWT (fine; retired end of 2026)" ;;
    sb_secret_*)      echo "  ✗ REFUSING: that is a SECRET key. It must never ship in the app." >&2; exit 1 ;;
    *)                echo "  ! unrecognised format — writing it anyway" ;;
  esac
  set_key SUPABASE_ANON_KEY "$KEY"
fi

printf 'USDA FoodData Central key (Enter to keep current): '
read -rs USDA; echo
if [ -n "$USDA" ]; then set_key USDA_API_KEY "$USDA"; echo "  ✓ USDA_API_KEY set"; fi

echo
echo "Done. Keys present (values hidden):"
sed -nE 's/^([A-Z_]+)[[:space:]]*=[[:space:]]*(.).*/  \1 = \2…/p' "$CFG"
echo
echo "Next: ./supabase/check-publishable-key.sh"
