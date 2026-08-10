---
description: Research and score an Executive Intake ask, then publish it to the ranking
argument-hint: [note name, or blank to score everything awaiting]
---

Score the Executive Intake entry: **$ARGUMENTS**

If no argument was given, score every note in `S0/Internal Builds/Pipeline Tracker/Intake/` whose `status` is `Awaiting scoring`, oldest `logged` first.

The human has supplied only the `verbatim`. Everything else is yours to produce.

## Do this in order

**1 · Read the ask and the rubric.**
Read the note, then `S0/Internal Builds/Pipeline Tracker/Scoring Rubric.md`. The 1–5 anchors are binding. Pull out the *qualifiers* in the verbatim — "if it's cheap", "eventually", "before the QBR" — they drive Urgency and Complexity and are the first thing lost in paraphrase.

**2 · Write the `interpreted` requirement.**
One sentence naming the deliverable, not the topic. Put it in both the frontmatter and the body.

**3 · Research what you can establish yourself — don't make the human look things up.**
- **Public web** for feasibility: API pricing and limits, third-party dependencies, whether the hard part is actually a solved problem. This is what makes Complexity honest.
- **This vault** for alignment: `S0/S0 Charter.md` (which workstream does it advance?), prior intake entries, `S0/Brainstorms/*.canvas` (the ask may already have a design sketch — check before you estimate).

**4 · Then ask the human everything research can't settle — and wait for the answers.**
Revenue ROI, client stakes, political weight, culture fit. Ask the person; don't reach for a CRM integration. Someone who was in the room answers better and faster than any connector.

Batch the questions into one message, and state which score each answer moves so they know what's at stake in replying. **Never guess at deal context — and never conclude a score before the answers arrive.**

**5 · Score all six, with one line of evidence each.**
Write the evidence into the note body under "Research pass". A score whose evidence you cannot state is not a score — go research it or score lower. Reminders:
- Urgency caps at **2** with no named external date. A standing SLA is not a deadline.
- Complexity **subtracts**. Score it honestly; deflating it to boost a favoured ask destroys the instrument.
- Values must be **unquoted integers** (`roi: 2`, never `roi: "2"`).

**6 · Propose the slot** — `Now` / `Next` / `Blocked` — with one line of reasoning. Say explicitly that the human should override it, since they can see capacity and you cannot.

**7 · Compute the total yourself as a cross-check**, state it, and read it against the rubric's bands. If it lands under 2.5, follow the rubric's instruction: propose what would make it **cheaper** — a thin slice that serves the same charter obligation — and record that option in the note. Never treat a low score as a rejection.

**8 · Set `status: Scored`.**

## Before you finish

- Run `ruby .tools/render-tracker.rb --check` — must print `OK`.
- Run `ruby .tools/render-tracker.rb` and confirm the row appears in the ranking section with the total you calculated by hand. If they disagree, the frontmatter is wrong (usually quoted numbers).
- Tell the human the score, the reasoning in two lines, and that it will reach the leadership-visible site at **the next publish cycle** (the operator sets that interval — don't state a number you haven't checked).

## Stop and ask instead of publishing if

You are uncertain enough that a wrong score would mislead leadership. Publishing is delayed but **unreviewed** — nobody is obliged to read your scores before leadership does, so the burden of not shipping a guess sits with you.
