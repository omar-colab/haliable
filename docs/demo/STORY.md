# The 3-minute story — "how I directed AI to build this"

Say it, don't read it. Every number below is real and checkable in this repo.
Practise it out loud twice. The bold lines are the ones to land; the rest can
flex.

---

## 0:00 — The problem (30s)

"I'm Muslim, and checking whether packaged food is halal means reading labels
for things like E471 or 'natural flavors' — ingredients that can come from
plants *or* animals, and the label doesn't say which. Different scholars also
rule differently. So I built **Haliable**: scan a barcode, and it tells you
whether the product is halal **under the standard you follow**, with the
scholarly source behind every flag."

## 0:30 — What I actually did (60s)

"I'm not a trained iOS developer. I built this by **directing AI agents like a
small team**, and my job was the decisions, not the typing.

- **I set the rules first.** The repo has a rules file the agents read before
  they touch anything. Rule one: *report, don't rule.* The app never decides
  what's halal. It reports what a published source said. Rule two: *a false
  'halal' is the one error I won't ship.* Unknown ingredients always come out
  as Questionable, never halal.
- **I made the AI prove things instead of claiming them.** 257 citations back
  148 of the 153 ingredient rulings. A validator refuses any reference that
  doesn't load, which is how I stop the AI from making up sources.
- **I ran a second agent as a reviewer** whose only job was to check the first
  one. It caught a real bug: the app was grading Nutella as haram, because
  'rum' matched inside the French word 'lactoserum'. That's a false ruling on a
  real brand, and it got caught before any user saw it."

## 1:30 — The moment that taught me the most (45s)

"**The scariest bug never showed up as a failure.** The backend library was
listed in the project but never actually linked to the app. So for months the
app quietly served fake sample data. Every build was green, and every test
passed.

I only caught it because the map kept showing stores I had deleted from the
database. The lesson I took: **a green build doesn't prove anything works. You
have to check the behavior against reality.** Now every phase ends with a
Release build and a check on a real device, not just 'tests pass'."

## 2:15 — Show it (30s)

Hand them the phone, or scan live:

- Something simple: **"Nothing flagged."**
- Something with gelatin or whey: **tap through the four standards and the
  verdict changes.** "Same product, different school of thought. It says so
  instead of pretending there's one answer."
- Something with caramel color: **"marked draft"**. "No scholar's ruling is
  attached yet, so it tells you."

## 2:45 — Close (15s)

"It's on TestFlight now. **What I'm proudest of isn't the code. It's that I
built the system that keeps AI honest: the rules, the reviewer, the citation
checks.** That's what I'd bring to your team."

---

### If they ask…

- **"How much did you write yourself?"**: "Very little of the Swift by hand. I
  wrote the rules, made every product decision, reviewed every change, and
  rejected a lot. The judgment calls were mine, and the agents executed them."
- **"What would you do next?"**: "Fill the last 5 citations, add a seafood
  standard, then a public App Store launch."
- **"What went wrong?"**: Use the never-linked library story. It's the honest
  one, and it shows you check your own work.
