#!/usr/bin/env python3
"""Review-request agent for Haliable. See PROTOCOL.md.

The agent researches; Omar decides; only `push` writes to the database.

    ./review_agent.py pull                 # pending requests -> briefs/
    ./review_agent.py stage <id>           # validate a researched draft
    ./review_agent.py review               # list staged drafts + their verdicts
    ./review_agent.py approve <id>         # Omar's gate
    ./review_agent.py reject  <id> "why"
    ./review_agent.py push                 # send approved drafts back to users

Needs, in the environment and never in the repo:
    SUPABASE_URL
    SUPABASE_SECRET_KEY     # sb_secret_… — bypasses RLS, server-side only

Dependency-free on purpose: stdlib only, so it runs with `python3 -I`.
"""

import argparse, json, os, re, sys, urllib.error, urllib.request
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
BRIEFS = HERE / "briefs"
DRAFTS = HERE / "drafts"
CITATIONS = HERE.parent.parent / "Haliable" / "Resources" / "Citations.json"
CANDIDATES = HERE / "candidates"

GRADES = ["halal", "doubtful", "haram"]          # worst-case order, ascending
CLEARING_TIERS = {1, 2}

# Ingredients whose ruling depends on what they were made from. Unspecified
# origin on any of these is unresolved — never halal. Mirrors the app's stance.
ORIGIN_SENSITIVE = {
    "gelatin", "enzymes", "enzyme", "whey", "mono- and diglycerides",
    "monoglycerides", "diglycerides", "l-cysteine", "cysteine", "glycerol",
    "glycerin", "lecithin", "rennet", "lipase", "pepsin", "shellac",
    "natural flavors", "natural flavours", "vitamin d3", "carmine",
}


# ---------------------------------------------------------------- supabase io

def _load_env_file():
    """Read scripts/review-agent/.env if present, so the key lives in one
    git-ignored file instead of a shell profile. Real environment variables
    always win, which keeps CI and one-off overrides working."""
    f = HERE / ".env"
    if not f.exists():
        return
    for line in f.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def _env(name):
    _load_env_file()
    v = os.environ.get(name)
    if not v:
        sys.exit(
            f"{name} is not set.\n"
            f"Put it in {HERE / '.env'} (git-ignored) — see .env.example.\n"
            "Never commit it and never paste it into a chat."
        )
    return v


def _rest(path, method="GET", body=None, params=""):
    url = f"{_env('SUPABASE_URL')}/rest/v1/{path}{params}"
    key = _env("SUPABASE_SECRET_KEY")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "apikey": key,                      # apikey ONLY — these keys are not JWTs
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read().decode()
    return json.loads(raw) if raw.strip() else []


# ---------------------------------------------------------------- validation

def fetch_ok(url):
    """A reference has to actually resolve. An unreachable source is rejected,
    not quietly downgraded."""
    if not re.match(r"^https?://", url or ""):
        return False, "not a URL"
    try:
        req = urllib.request.Request(url, method="GET", headers={
            "User-Agent": "Haliable-ReviewAgent/1.0 (+https://haliable.netlify.app)"})
        with urllib.request.urlopen(req, timeout=25) as r:
            return (200 <= r.status < 300), f"HTTP {r.status}"
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code}"
    except Exception as e:
        return False, type(e).__name__


def validate(draft, check_urls=True):
    """Every rule in PROTOCOL.md, checked mechanically. Returns a list of
    problems; empty means the draft may be staged."""
    problems = []
    ings = draft.get("ingredients") or []
    if not ings:
        problems.append("no ingredients — nothing to rule on")

    worst = 0
    unresolved = []

    for ing in ings:
        name = (ing.get("name") or "").strip()
        if not name:
            problems.append("an ingredient has no name")
            continue
        sources = ing.get("sources") or []
        clearing = [s for s in sources if s.get("tier") in CLEARING_TIERS]

        for s in sources:
            for field in ("sourceName", "reference", "date", "tier", "paraphrase"):
                if not s.get(field):
                    problems.append(f"{name}: source missing `{field}`")
            if s.get("tier") not in (1, 2, 3):
                problems.append(f"{name}: tier must be 1, 2 or 3")
            if len((s.get("paraphrase") or "")) < 40:
                problems.append(f"{name}: paraphrase too thin to check the verdict against")
            if check_urls and s.get("reference"):
                ok, why = fetch_ok(s["reference"])
                if not ok:
                    problems.append(f"{name}: reference does not resolve ({why}) — {s['reference']}")

        grade = (ing.get("grade") or "").strip().lower()
        if grade not in GRADES:
            problems.append(f"{name}: grade must be one of {GRADES}")
            continue

        # Rule: origin-sensitive ingredients need their origin stated.
        if name.lower() in ORIGIN_SENSITIVE and not (ing.get("origin") or "").strip():
            if grade == "halal":
                problems.append(
                    f"{name}: origin-sensitive and origin not stated — cannot be halal")

        # Rule: no clearing source means unresolved, which is never halal.
        if not clearing:
            unresolved.append(name)
            if grade == "halal":
                problems.append(
                    f"{name}: no Tier 1/2 source — unresolved cannot be returned as halal")

        worst = max(worst, GRADES.index(grade))

    # Rule: worst-case rollup.
    stated = (draft.get("verdict") or "").strip().lower()
    if stated not in GRADES:
        problems.append(f"verdict must be one of {GRADES}")
    elif GRADES.index(stated) != worst:
        problems.append(
            f"verdict `{stated}` is not the worst ingredient grade `{GRADES[worst]}` "
            "— worst-case rollup is not optional")

    if unresolved and stated == "halal":
        problems.append(f"unresolved ingredients present ({', '.join(unresolved)}) — not halal")

    if not (draft.get("reply") or "").strip():
        problems.append("no reply written for the user")
    elif unresolved and not any(u.lower() in draft["reply"].lower() for u in unresolved):
        problems.append("reply must name the unresolved ingredient(s)")

    return problems


# ---------------------------------------------------------------- commands

def cmd_pull(args):
    BRIEFS.mkdir(exist_ok=True)
    cells = {}
    if CITATIONS.exists():
        data = json.loads(CITATIONS.read_text())
        for c in data.get("cells", []):
            cells.setdefault(c.get("subject", "").lower(), []).append(c)

    rows = _rest("review_requests", params="?status=eq.pending&order=created_at.asc&limit=50")
    if not rows:
        print("nothing pending.")
        return
    for r in rows:
        brief = {
            "request_id": r["id"],
            "product_name": r.get("product_name"),
            "barcode": r.get("barcode"),
            "user_notes": r.get("notes"),
            "photo_paths": r.get("photo_paths") or [],
            "submitted": r.get("created_at"),
            "instructions": "Fill `ingredients`. See ../PROTOCOL.md. "
                            "Every ingredient needs a grade; anything without a "
                            "Tier 1/2 source is unresolved and cannot be halal.",
            "verdict": "",
            "reply": "",
            "ingredients": [{
                "name": "", "origin": "", "grade": "",
                "already_cited": False,
                "sources": [{"sourceName": "", "reference": "", "date": "",
                             "tier": 0, "paraphrase": ""}],
            }],
            "_citations_json_has": sorted(cells.keys()),
        }
        out = BRIEFS / f"{r['id']}.json"
        out.write_text(json.dumps(brief, indent=2))
        print(f"brief  {out.relative_to(HERE)}  — {r.get('product_name') or r.get('barcode') or 'unnamed'}")
    print(f"\n{len(rows)} pending. Research them, then: ./review_agent.py stage <id>")


def cmd_stage(args):
    DRAFTS.mkdir(exist_ok=True)
    CANDIDATES.mkdir(exist_ok=True)
    src = BRIEFS / f"{args.request_id}.json"
    if not src.exists():
        sys.exit(f"no brief at {src}")
    draft = json.loads(src.read_text())

    problems = validate(draft, check_urls=not args.skip_url_check)
    if problems:
        print(f"NOT staged — {len(problems)} problem(s):\n")
        for p in problems:
            print(f"  - {p}")
        sys.exit(1)

    draft["decision"] = "staged"
    draft["staged_at"] = datetime.now(timezone.utc).isoformat()
    (DRAFTS / f"{args.request_id}.json").write_text(json.dumps(draft, indent=2))

    # Feed the existing citation pipeline so the matrix improves too.
    made = 0
    for ing in draft["ingredients"]:
        clearing = [s for s in ing.get("sources", []) if s.get("tier") in CLEARING_TIERS]
        if ing.get("already_cited") or not clearing:
            continue
        cand = {
            "target": {"kind": "cell", "subject": ing["name"],
                       "origin": ing.get("origin") or "unspecified",
                       "position": draft.get("position", "general")},
            "proposed": clearing,
            "researcherNote": f"From review request {args.request_id}.",
            "decision": "staged",
        }
        (CANDIDATES / f"{args.request_id}-{ing['name'].replace(' ', '-')}.json").write_text(
            json.dumps(cand, indent=2))
        made += 1

    print(f"staged. verdict={draft['verdict']}")
    if made:
        print(f"{made} citation candidate(s) written for the matrix pipeline.")
    print("Omar: ./review_agent.py review")


def cmd_review(args):
    if not DRAFTS.exists() or not any(DRAFTS.glob("*.json")):
        print("nothing staged.")
        return
    for f in sorted(DRAFTS.glob("*.json")):
        d = json.loads(f.read_text())
        print(f"\n{'='*72}\n{d['request_id']}  [{d.get('decision')}]  "
              f"{d.get('product_name') or d.get('barcode') or ''}")
        print(f"VERDICT: {d['verdict'].upper()}")
        for ing in d["ingredients"]:
            tiers = ",".join(str(s["tier"]) for s in ing.get("sources", [])) or "-"
            print(f"   {ing['grade']:9} {ing['name']:28} origin={ing.get('origin') or '?':14} tiers={tiers}")
            for s in ing.get("sources", []):
                print(f"              T{s['tier']} {s['sourceName']} — {s['reference']}")
        print(f"\nREPLY TO USER:\n  {d['reply']}")
    print(f"\n{'='*72}\napprove: ./review_agent.py approve <id>   reject: ./review_agent.py reject <id> \"why\"")


def _set_decision(request_id, decision, note=None):
    f = DRAFTS / f"{request_id}.json"
    if not f.exists():
        sys.exit(f"no staged draft for {request_id}")
    d = json.loads(f.read_text())
    d["decision"] = decision
    if note:
        d["owner_note"] = note
    d["decided_at"] = datetime.now(timezone.utc).isoformat()
    f.write_text(json.dumps(d, indent=2))
    print(f"{request_id} -> {decision}")


def cmd_approve(args): _set_decision(args.request_id, "approved")
def cmd_reject(args):  _set_decision(args.request_id, "rejected", args.reason)


def cmd_push(args):
    approved = [f for f in DRAFTS.glob("*.json")
                if json.loads(f.read_text()).get("decision") == "approved"]
    if not approved:
        print("nothing approved to push.")
        return
    for f in approved:
        d = json.loads(f.read_text())
        # Re-validate at the boundary. Approval is not a bypass.
        problems = validate(d, check_urls=False)
        if problems:
            print(f"REFUSED {d['request_id']}: {problems[0]}")
            continue
        _rest("review_requests", method="PATCH",
              params=f"?id=eq.{d['request_id']}",
              body={"status": "completed",
                    "verdict": d["verdict"],
                    "verdict_reason": d["reply"],
                    "evidence": d["ingredients"],
                    "reviewed_at": datetime.now(timezone.utc).isoformat()})
        d["pushed_at"] = datetime.now(timezone.utc).isoformat()
        f.write_text(json.dumps(d, indent=2))
        print(f"pushed {d['request_id']} — {d['verdict']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("pull").set_defaults(fn=cmd_pull)
    p = sub.add_parser("stage"); p.add_argument("request_id")
    p.add_argument("--skip-url-check", action="store_true",
                   help="skip fetching references (offline only — never before push)")
    p.set_defaults(fn=cmd_stage)
    sub.add_parser("review").set_defaults(fn=cmd_review)
    p = sub.add_parser("approve"); p.add_argument("request_id"); p.set_defaults(fn=cmd_approve)
    p = sub.add_parser("reject"); p.add_argument("request_id"); p.add_argument("reason")
    p.set_defaults(fn=cmd_reject)
    sub.add_parser("push").set_defaults(fn=cmd_push)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
