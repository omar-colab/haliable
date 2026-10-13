#!/usr/bin/env bash
# Apply the Haliable backend schema to a Supabase project, in order.
#
#   ./supabase/apply-migrations.sh abumevloleevhoqxfnoe
#
# Uses `supabase db query`, which goes through the Management API with your
# `supabase login` session — no database password required.
#
# Every file is idempotent (create if not exists / on conflict do nothing), so
# re-running is safe. Stops at the first failure rather than carrying on.
set -euo pipefail
cd "$(dirname "$0")/.."

REF="${1:-}"
if [ -z "$REF" ]; then
  echo "usage: $0 <project-ref>" >&2
  exit 2
fi

FILES=(
  supabase-setup.sql
  supabase/migrations/0001_stores_atlas.up.sql
  supabase/migrations/0002_seed_stores.up.sql
  supabase/migrations/0003_stores_submit.up.sql
  supabase/migrations/0004_rls_hardening.up.sql
  supabase/migrations/0005_store_votes.up.sql
  supabase/migrations/0006_account_lifecycle.up.sql
  supabase/migrations/0007_real_stores.up.sql
)

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "skip (missing): $f"; continue; }
  printf '→ %-52s' "$f"
  if supabase db query --project-ref "$REF" -f "$f" >/tmp/haliable-mig.out 2>&1; then
    echo "ok"
  else
    echo "FAILED"
    echo "---"
    cat /tmp/haliable-mig.out
    exit 1
  fi
done

echo
echo "All migrations applied to $REF."
echo "Next: supabase db query --project-ref $REF -f supabase/tests/rls_matrix.sql"
