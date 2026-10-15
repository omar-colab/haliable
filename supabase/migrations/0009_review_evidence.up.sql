-- 0009 — keep the evidence behind a human ruling.
--
-- `verdict_reason` is prose written for the user. It is not an audit trail: it
-- cannot say which body was cited, at what tier, or on what date. Rule 3 says
-- the app reports published positions rather than issuing opinions, so a ruling
-- that cannot be traced back to its sources is indistinguishable from one the
-- app invented.
--
-- `evidence` stores the per-ingredient source blocks the review agent validated
-- (scripts/review-agent/PROTOCOL.md). Additive and nullable: every existing row
-- and every current client keeps working untouched.

alter table public.review_requests
  add column if not exists evidence jsonb;

comment on column public.review_requests.evidence is
  'Per-ingredient sources behind the verdict: [{name, origin, grade, sources:[{sourceName, reference, date, tier, paraphrase}]}]. Written only by the review agent after the owner approves.';

-- No RLS change. Users already read their own rows and still cannot UPDATE —
-- the agent writes with the secret key, server-side, exactly as before.
