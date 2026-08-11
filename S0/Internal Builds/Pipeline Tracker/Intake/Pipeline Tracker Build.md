---
tags:
  - executive-intake
verbatim: '[paraphrase] Board capture only. The whiteboard recorded the topic "Pipeline Tracker", a cc: marker denoting a verbal directive from the CEO, and a ranking table of six columns — Name, Description, Revenue ROI score, Culture Score, Complexity Score, and Overall Score (used for ranking). The words actually spoken were not preserved.'
interpreted: A ranked, evidence-backed queue for Executive Intake asks, so that a directive which cannot be refused can at least be sequenced — scored on declared criteria, auto-totalled so nobody negotiates their own number, and visible to leadership without anyone having to ask where a request stands.
logged: 2026-08-11
logged_by: R. Kashyap
shipped: 2026-08-11
roi: 2
strategic: 3
impact: 4
urgency: 2
culture: 4
complexity: 2
slot: Done
status: Shipped
---

## Verbatim — what was actually said

> **[paraphrase]** Board capture only. The whiteboard recorded the topic *"Pipeline Tracker"*, a `cc:` marker denoting a verbal directive from the CEO, and a ranking table of six columns — Name, Description, Revenue ROI score, Culture Score, Complexity Score, and Overall Score (used for ranking).

**The spoken words were not preserved.** Board source: [[2026-08-10 Whiteboard Brainstorm.canvas]], `Pipeline Tracker` cluster — transcribed from a whiteboard photo on 2026-08-10; the original board was not otherwise kept. The canvas's own capture note records that the column list was **confirmed through follow-up Q&A**, so the score columns below are a verified requirement, not a transcription guess.

This entry is logged retrospectively, after delivery. Everything that follows is reconstructed from artifacts and git history, and says so wherever it is reconstructed.

## Interpreted requirement

A ranked, evidence-backed queue for Executive Intake asks — so that a directive which cannot be refused can at least be sequenced. Scored on declared criteria, auto-totalled so nobody negotiates their own number, and visible to leadership without anyone having to ask where a request stands.

## Delivered vs asked — the scope delta

Three scoring dimensions were requested. Six shipped.

| Asked for | Delivered | Direction |
|---|---|---|
| Name | Note filename → the Ask column | as asked |
| Description | Split into **two** fields, `verbatim` and `interpreted` | added — the split was not requested |
| Revenue ROI score | `roi`, weight 0.30 | as asked |
| Culture Score | `culture`, weight 0.15 | as asked |
| Complexity Score | `complexity`, weight 0.25, **subtracted** | as asked; the subtraction was our reading |
| Overall Score, used for ranking | Computed formula, auto-sorted, never typed | as asked |
| — | **Strategic Alignment**, weight 0.20 | added |
| — | **Client Impact / Visibility**, weight 0.20 | added |
| — | **Urgency**, weight 0.15 | added |
| — | [[Scoring Rubric]] — 1–5 anchors for all six dimensions | added |
| — | Slot vocabulary: Now / Next / Blocked | added |
| — | Published web view | added |
| — | CI that refuses to deploy a ranking it cannot verify | added |

**The number worth carrying into the recalibration: 0.55 of the 1.00 value weight comes from dimensions nobody asked for.** Strategic 0.20 + Impact 0.20 + Urgency 0.15. Of the requested dimensions, ROI and Culture carry 0.45 between them; Complexity is the subtracted term rather than part of the value total.

This is not an argument that the additions are wrong — all three are defensible and the rubric documents why. It is a prediction about where disagreement will land. **If leadership looks at the ranking and disagrees with the order, the likeliest cause is a criterion they never requested.** So the recalibration hour the Executive Brief asks for should open with this table, not with the weights.

## What actually shipped

| Artifact | Role |
|---|---|
| [[Priority Ranking.base]] | The live tracker. Formula, column set, two views. Single source of truth for the weights. |
| [[Scoring Rubric]] | 1–5 anchors per dimension. The reason two people score alike. |
| [[Pipeline Tracker]] | Operating doc — the flow, the model, how to run it. |
| [[Publishing]] | Publish runbook, and what publishing a whole note body means on a public site. |
| [[Executive Intake Entry]] | Capture template for a new ask. |
| [[Executive Intake Entry (Shipped)]] | Retrospective template. This entry is its first use. |
| `.tools/render-tracker.rb` | Renders base + intake notes to self-contained HTML. Ruby 2.6-compatible, no gems. Parses the weights out of the `.base`. |
| `.github/workflows/publish-tracker.yml` | verify → render → deploy on every relevant push. |
| GitHub Pages site, public | The leadership-visible read-only view, at https://robertkashyap-searce.github.io/s0/. No sign-in; publishing an entry publishes its whole body. |
| `CLAUDE.md` | In-repo agent harness — the division of labour that keeps scoring off the human's desk. |
| `README.md` (root and tracker) | Entry points for anyone arriving from GitHub. |
| `Pipeline Tracker — Executive Brief.md` | CEO-facing brief; asks for endorsement and one hour per cycle. Kept **outside** the vault, so it is not wikilinked here. |

## Research pass — one line of evidence per score

Anchors: [[Scoring Rubric]].

- **Revenue ROI — 2.** Anchor 2 exactly: *"indirect support only — better collateral, easier future pitch."* The tracker closes nothing; it sequences. Its commercial effect is one step removed — it is the mechanism by which revenue-bearing asks outrank curiosities, and it produced CEO-facing collateral. No named pursuit depended on it. Not 1, because the line of sight exists even though it is indirect.
- **Strategic Alignment — 3.** Anchor 3: *"fits a charter slice cleanly"* — the Internal Builds 20%. **Not 4**, because anchor 4 names four frontier workstreams ([[Frontier Radar]], [[Benchmark Discipline]], [[Architecture Hub]], [[Field Response Desk]]) and this is none of them. **Contestable at 4:** this is the instrument that makes a hot-desk cap breach visible *before* it happens, which protects the sacred 40% and the charter's *"contract integrity"* success criterion. If leadership reads charter machinery as frontier-advancing, this is a 4 and the total is **2.60**. Recorded rather than quietly resolved.
- **Client Impact — 4.** Anchor 4: *"touches a live client commitment **or an exec-level audience**."* The output is a leadership-visible page, and a dedicated brief asks the CEO for endorsement and an hour per cycle. Not 5: no client sees it and no must-win moment attaches. *Also hits the known anchor gap — public/brand visibility with no client behind it. Third entry to hit it.*
- **Urgency — 2.** The anchor caps undated items at 2. **Verified against the board, not assumed:** the `AIOS` node carries *"ToBe — deadline 15 Aug 2026"*; the `Pipeline Tracker` node carries no date at all. Wanted soon, no fixed date.
- **Culture — 4.** Anchor 4: *"builds capability in ≥2 people, or yields a teach-in."* The build produced working knowledge of Obsidian Bases formulas, weighted scoring with a subtracted cost term, a gem-free Ruby renderer, and a CI path that renders and deploys a static site unattended — and the operating docs are the teach-in artifact. *(The host and the gating it carried at build time have since been retired for GitHub Pages with no gate. Score unchanged: the capability the build produced was the pipeline, not the vendor.)* **Contestable at 3:** if one person built it alone and nobody else has since touched it, anchor 4's *"≥2 people"* fails, this becomes a 3 (*"produces a documented pattern"*), and the total drops to **2.25**. A human should settle this; the artifacts cannot.
- **Complexity — 2.** Anchor 2: *"~2 days."* Evidenced from git: first commit 2026-08-10, last substantive commit 2026-08-11, 14 commits of which roughly 10 are substantive — the `vault backup:` commits are Obsidian Git's timer, not work. **The anchor's other half does not hold:** the path was *not* known. Obsidian Publish cannot render Bases (confirmed by Obsidian staff, 10 Oct 2025), so a renderer had to be written rather than a product configured. Scored on realised duration; that tension is itself a finding, below.

**Overall = 2.40.** Band 1.5–2.5: *"weak, or valuable-but-expensive."*

### Complexity: what the anchors would have predicted vs what it cost

- **Anchors would have supported 4 at ask-time** — *"multi-week. Real unknowns or external dependencies."* Three external dependencies (Obsidian Bases, GitHub Actions, and the third-party host and auth gate used at the time) is anchor 4's literal condition, and the central question — *can this ranking be published at all?* — had no known answer. **This figure is reconstructed now; nobody recorded an estimate at the time.**
- **Actual, evidenced: 2.** Two calendar days, ten substantive commits, every dependency navigated without a surviving blocker.
- **Delta: 2 points, worth 0.50 on the Overall.** What it says about the anchors: they conflate *number of dependencies* with *cost*. Three well-documented SaaS dependencies cost less than one undocumented one. Dependency count is a poor proxy; what predicts cost is whether each dependency has a documented happy path. **Proposed anchor revision:** score Complexity on unknowns *without documented answers*, not on how many external systems are involved.

## Validation — what was checked, and how

| What we checked | How | Result |
|---|---|---|
| The arithmetic is correct | Fixed fixture `(4,5,5,4,3,3)` against an independently computed expected total of 3.50 | **Verified** |
| Weights cannot drift between site and vault | Renderer parses the coefficients *out of* the `.base` formula rather than duplicating them | **Verified by construction** |
| Half-scored rows stay unscored | `--check` asserts `compute_overall` returns nil rather than totalling to 0 | **Verified** |
| Retractions disappear from the site | Full rebuild and full-directory upload on every run | **Verified** |
| Only the allowlisted notes reach the page | `DOCS` in the renderer is a declared list — `Intake/*.md` plus two reference docs — and an off-list wikilink renders as plain text rather than a link | **Verified by construction** |
| The path works unattended | Changed one score, observed it reach the published page with no manual step | **Verified** |
| The Overall column renders inside Obsidian | — | **Not verified.** The website was checked; the in-Obsidian base formula column was not. Carried as a limit, not a pass. |

**Amended 2026-08-12.** This table previously carried a row recording that the page was not publicly readable. **Hosting has since moved to GitHub Pages and the site is public by decision of the repo owner**, so that row was retired rather than left standing as a false pass. The allowlist row above is what is verifiable now.

Two findings are worth keeping, because they are why the result is trustworthy. First, the automated check originally asserted against a **live note**, so every legitimate re-score registered as a mismatch and blocked publication — correct behaviour looked like a fault. It was repointed at a fixture. Found by validation, not by a user. Second, the system **stops rather than publishing what it cannot verify**: a failed check leaves the previous version visible. A ranking one cycle stale is recoverable; a wrong one is not.

## Deliberately not built

- **Automated intake.** The source is a person talking; there is nothing to poll, and building one would mean changing how leadership communicates to suit a tool. *Trigger to revisit: asks start arriving in writing.*
- **Automated research and scoring.** Scores must be defensible in front of the CEO, and commercial context sits with people. *Trigger: ~10 real entries exist to calibrate machine suggestions against — which is also the point at which weight recalibration first has data.*
- **Effort estimates in hours.** 1–5 is enough to rank; hours are a planning artifact and would add false precision at the point of prioritisation. *Trigger: none currently foreseen.*
- ~~**A separate table for shipped rows.**~~ **Deferred, then built the same hour.** The deferral read: *"trigger: enough shipped entries to crowd the queue — this is the first, so the question is not live yet."* It was wrong. The first render put this entry, complete and delivered, at **#1 under a heading that says "Priority ranking"** — above live work, on an unattended publish to a CEO. The trigger was never a crowd; it was one Done row outscoring one open row. The renderer now partitions Shipped into its own table. *Kept visible rather than edited away, because the failure mode is the useful part: a threshold expressed as a volume ("enough to crowd") missed a condition that fires at n=1.*

## Known limits carried into production

- **The weights are not empirically validated.** They encode a defensible starting position. Note specifically that Complexity at 0.25 outweighs Strategic Alignment at 0.20, which biases the ranking toward cheap work — a real concern against a 40% research mandate.
- **Two anchor gaps remain open** — Client Impact has no anchor for public/brand visibility with no client attached; Urgency does not distinguish a standing SLA from a fixed external date. Three entries have now hit the first.
- **Assessment capacity is the ceiling,** at roughly fifteen requests a cycle. Recording never stops; assessment is what queues, and queue depth is the signal for a capacity conversation.
- **Staying current needs a device.** The site stays *live* unattended; getting an edit into GitHub needs something that has synced.
- **The whole vault sits in a third-party private repo,** including [[Benchmark Discipline]], which is marked internal-only. A private repo is not publication, but it is a third party holding it. Revisit if that reading tightens.
- **No redaction layer, and readers are not internal.** *(Amended 2026-08-12: this limit previously read "correct while readers are internal" and treated a widening to clients as hypothetical. The site is now on GitHub Pages with no gate, so the readership has already widened to anyone.)* The redaction pass has to happen in the note body at writing time, because there is no layer downstream to do it — a client reading their own ROI score of 2 is an incident, not a transparency win.
- **Culture scores are visible to the people they describe, and to everyone else.** *(Amended 2026-08-12: previously scoped to squad members.)* Per-colleague reasoning about a named colleague publishes verbatim to a public page; it should be a deliberate yes from the writer, not a surprise to the person named.
- **The renderer aborts rather than skips on a blank score** in any row whose status is not `Awaiting scoring`. It fails safe and loud — by design, a stale ranking beats a wrong one — but the failure surfaces as a Ruby type error rather than a message naming the offending row.
- **The base excludes templates by exact filename,** so every new template carrying the `executive-intake` tag needs its own exclusion line or it appears as a phantom row in Obsidian.

## Findings for the next recalibration

1. **0.55 of the ranking weight was never requested.** See the scope-delta table. Open the recalibration with it.
2. **The Complexity anchors overestimated this build by 2 points** by counting dependencies instead of undocumented unknowns. Proposed revision recorded above.
3. **Internal governance work cannot score well by construction.** ROI and Urgency carry 0.45 of the weight between them, and both floor out for work with no deal and no date. This entry — the instrument itself, complete, validated, cheap, and CEO-facing — scores **2.40**, below the mid-band. Either that is correct and governance genuinely should rank below revenue work, or the rubric needs a defined path for internal instruments. **That should be an explicit decision, not a drift.** Note that [[Content Generator]] reached the same conclusion from the opposite direction: ROI, not Complexity, is what binds.
4. **Client Impact anchor gap** — public/brand visibility with no client behind it. Third entry to hit it.
5. **Urgency anchor gap** — standing SLA versus fixed external date.
6. **The slot vocabulary needed a fourth value.** `Done` was added to [[Scoring Rubric]] for this entry; Now / Next / Blocked had no way to say "delivered."
7. **Logging delivered work changed the page, not just the data.** A ranked list of *asks* and a record of *outcomes* are two different documents; putting the second into the first inverted the meaning of the top row. Shipped rows now render separately. Worth remembering before the next field is added: on an unattended publish, a schema change is a change to what leadership reads, and there is no reviewer in between.
