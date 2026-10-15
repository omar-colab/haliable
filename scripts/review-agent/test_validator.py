#!/usr/bin/env python3
"""Checks the review-agent validator refuses what PROTOCOL.md says it must.

    python3 -I scripts/review-agent/test_validator.py

URL fetching is off here — these assert the reasoning rules, not the network.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from review_agent import validate

T1 = {"sourceName": "JAKIM MS1500:2019", "reference": "https://example.org/ms1500",
      "date": "2019", "tier": 1,
      "paraphrase": "Gelatin derived from non-zabiha bovine hide is impermissible "
                    "under this standard unless the source animal was slaughtered Islamically."}
T3 = dict(T1, tier=3, sourceName="A halal blog")


def check(name, draft, must_contain=None, expect_ok=False):
    problems = validate(draft, check_urls=False)
    if expect_ok:
        assert not problems, f"{name}: expected clean, got {problems}"
    else:
        assert problems, f"{name}: expected a refusal, got none"
        if must_contain:
            joined = " | ".join(problems).lower()
            assert must_contain.lower() in joined, f"{name}: wanted '{must_contain}', got {problems}"
    print(f"  ok  {name}")


print("review-agent validator")

# A clean, fully-sourced haram ruling passes.
check("clean haram draft", {
    "verdict": "haram",
    "reply": "Contains gelatin of unstated origin, which JAKIM treats as impermissible.",
    "ingredients": [{"name": "gelatin", "origin": "bovine, non-zabiha",
                     "grade": "haram", "sources": [T1]}],
}, expect_ok=True)

# Tier 3 alone cannot clear anything.
check("tier 3 cannot clear", {
    "verdict": "halal", "reply": "Looks fine.",
    "ingredients": [{"name": "sugar", "origin": "cane", "grade": "halal", "sources": [T3]}],
}, must_contain="no Tier 1/2 source")

# Worst-case rollup is not optional.
check("rollup must take the worst", {
    "verdict": "doubtful",
    "reply": "Mixed.",
    "ingredients": [
        {"name": "sugar", "origin": "cane", "grade": "halal", "sources": [T1]},
        {"name": "pork", "origin": "pig", "grade": "haram", "sources": [T1]},
    ],
}, must_contain="worst-case rollup")

# Origin-sensitive ingredients cannot be halal with origin unstated.
check("origin-sensitive needs an origin", {
    "verdict": "halal", "reply": "Fine.",
    "ingredients": [{"name": "whey", "origin": "", "grade": "halal", "sources": [T1]}],
}, must_contain="origin-sensitive")

# Silence is never permission.
check("unresolved is not halal", {
    "verdict": "halal", "reply": "Fine.",
    "ingredients": [{"name": "natural flavors", "origin": "plant",
                     "grade": "halal", "sources": []}],
}, must_contain="unresolved")

# The user must be told what could not be resolved.
check("reply must name the unresolved", {
    "verdict": "doubtful",
    "reply": "We could not confirm this product.",
    "ingredients": [{"name": "lipase", "origin": "microbial",
                     "grade": "doubtful", "sources": []}],
}, must_contain="must name the unresolved")

# A paraphrase has to be substantive enough to audit the verdict against.
check("thin paraphrase rejected", {
    "verdict": "haram", "reply": "Contains gelatin.",
    "ingredients": [{"name": "gelatin", "origin": "porcine", "grade": "haram",
                     "sources": [dict(T1, paraphrase="not allowed")]}],
}, must_contain="paraphrase too thin")

print("\nall validator checks passed")
