---
tags:
  - executive-intake
verbatim: 
interpreted: 
logged: {{date}}
logged_by: 
shipped: 
roi: 
strategic: 
impact: 
urgency: 
culture: 
complexity: 
slot: Done
status: Awaiting scoring
---

## What this template is for

An ask that has **already been delivered**, logged retrospectively so the ranking
carries a record of what shipped and what it actually cost.

Use [[Executive Intake Entry]] for anything not yet built. The two differ in one
substantive way: a shipped entry scores Complexity against **what the work
actually cost**, not an estimate — which is the only way the rubric ever gets
calibrated.

> [!warning] Leave `status: Awaiting scoring` until all six scores are filled
> The renderer formats an Overall for every row whose status is not
> `Awaiting scoring`. A row with a blank score has no Overall, and formatting a
> blank aborts the render — which fails CI and blocks the deploy.
> **Fill all six scores, then set `status: Shipped`.**
> That is why this template ships with the awaiting status even though the work
> is done. Don't "correct" it.

---

## Verbatim — what was actually said

> 

Exact words, no cleaning up. If you're working from a board photo, a summary, or
memory rather than the words themselves, write `[paraphrase]` and say where it
came from. **A retrospective entry is the easiest place to invent a verbatim** —
the work is already finished, so a tidy version of the ask reads as plausible.
Don't.

Copy the same line into the `verbatim` property above so it shows on the tracker.

## Interpreted requirement

*What we believed was being asked for.*

## Delivered vs asked — the scope delta

The gap between the verbatim and what shipped, in both directions:

| Asked for | Delivered | Direction |
|---|---|---|
|  |  | as asked / added / dropped |

**Fill this in even when it's empty, and say so if it is.** Additions matter as
much as omissions: scope nobody requested still consumed the slice it was charged
to, and it stays invisible unless it's written here.

## What actually shipped

The artifacts anyone would open to see the thing:

| Artifact | Role |
|---|---|
|  |  |

## Research pass — one line of evidence per score

Anchors: [[Scoring Rubric]]. Score against what the entry can evidence, not
against how the work feels now that it exists and works.

- **Revenue ROI —**
- **Strategic Alignment —**
- **Client Impact —**
- **Urgency —** *(score the date pressure that existed at ask-time, not the fact that it's now done)*
- **Culture —**
- **Complexity —** *(the actual cost, evidenced: commits, elapsed days, dependencies that materialised)*

**Overall = ** *(computed by the tracker, never typed)*

### Complexity: what the anchors would have predicted vs what it cost

The one thing a shipped entry can contribute that no open entry can. State both —
and say plainly that the ask-time figure is **reconstructed now**, not a number
anyone recorded at the time, or it reads as a contemporaneous estimate.

- **Anchors would have supported at ask-time:** *n*, because …
- **Actual, evidenced:** *n*, because …
- **Delta, and what it says about the anchors:**

## Validation — what was checked, and how

| What we checked | How | Result |
|---|---|---|
|  |  |  |

Distinguish **verified** from **assumed**. Anything unverified is a known limit,
below — not a passing row here.

## Deliberately not built

What was considered and consciously left out, each with the trigger that would
change the answer. A deferral with no trigger is just a gap.

- 

## Known limits carried into production

What is live and imperfect. Not open questions — accepted costs, written down so
nobody has to re-derive them later.

- 

## Findings for the next recalibration

What building this taught us about the instrument itself: anchor gaps, weight
problems, vocabulary that didn't fit. This is the section that compounds.

- 
