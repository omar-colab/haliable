-- Reverses 0009. Dropping the column discards the audit trail for every ruling
-- already answered, so take a copy first if those rulings still matter.
alter table public.review_requests
  drop column if exists evidence;
