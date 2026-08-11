---
tags:
  - executive-intake
verbatim: we need to build a content engine that gets triggered from some feed from twitter based on AI or ML based advancements from some script or so and then goes via an engine of research, which feeds writer persona -> feeds the formatting system -> feeds verifier agent and outputs to medium blogs/twitter/linkedin; also we might have a POC producer from the articles in far future
interpreted: An agent chain that turns a new AI/ML release into a Searce-agnostic release analysis — researched, drafted in a house voice, formatted, automatically checked, then approved by a human and an external reviewer before publishing to Medium, X and LinkedIn.
logged: 2026-08-11
logged_by: R. Kashyap
roi: 2
strategic: 4
impact: 3
urgency: 2
culture: 4
complexity: 4
slot: Next
status: Scored
---

## Verbatim — what was actually said

> "We need to build a content engine that gets triggered from some feed from Twitter based on AI or ML based advancements from some script or so, and then goes via an engine of research, which feeds writer persona → feeds the formatting system → feeds verifier agent, and outputs to Medium blogs / Twitter / LinkedIn. Also we might have a POC producer from the articles in far future."

Board capture: [[2026-08-10 Whiteboard Brainstorm.canvas]], `Content Generator` cluster. Re-logged 2026-08-11 after a full requirements pass.

## Interpreted requirement

An agent chain that turns a new AI/ML release into a Searce-agnostic release analysis — researched, drafted in a house voice, formatted, automatically checked, then approved by a human *and* an external reviewer before publishing to Medium, X and LinkedIn.

**Qualifiers heard:** *"some script or so"* — ingestion was never chosen, only gestured at. *"we might have a POC producer… in far future"* — since retracted (see below); the output is a conclusion, not a build.

---

## Design resolved 2026-08-11

Settled with the requester across five question rounds. These are decisions, not assumptions.

| Question | Resolved |
|---|---|
| Charter relationship | A **subplan inside [[Frontier Radar]]**. The 48h cadence applies. **No client-shaped evaluation** — assessment happens at the level of the release itself |
| Confidentiality | Content is **Searce-agnostic**. No client data, no [[Benchmark Discipline]] data. The firewall is the content rule itself, not a downstream filter |
| Output | Two renders from one canonical brief: a **150–300 word social post + thread** (X, LinkedIn), and a **TL;DR + bullets brief with expandable long form** (Medium) |
| Positioning | Majority about the product. A **passive** hint of Searce capability — never an active claim |
| "Sig" | **Signature** — a house style/voice spec the formatter enforces. A spec file plus per-channel templates |
| Personas | **Two** — a social voice and a long-form voice, sharing one set of facts |
| Byline | **Brand** (Searce / squad), not an individual |
| Publish gate | **A human approves every publish.** Nothing ships unattended |
| External sign-off | **Required.** Someone outside S0 approves each piece; they have committed to a turnaround inside the window |
| Verifier scope | Four automated checks: every claim traces to a cited source · numbers match the source exactly · no Searce client/internal/benchmark data · claim strength not overstated. A human still reviews all four |
| On verification failure | **One bounded rewrite** with the findings, then queued for a human either way, findings attached |
| Runtime | **Inside Claude Code** — subagents and commands over vault files |
| Channels for v1 | **Manual paste.** No platform API work; revisit only if volume demands it |
| Time slice | **Frontier 40%**, as Radar machinery |
| Success measure | **Reach** — reads, follows, engagement |
| POC producer | **Retracted.** Not POC-tied — the deliverable is a conclusion |

### Recorded objection, overruled

Charging the *build* to the frontier 40% was queried: the charter calls that slice sacred and fills it with research, builds, papers and eval sweeps, and tooling that produces content is closer to a platform. The requester chose frontier anyway, on the grounds that this is Radar machinery. Recorded here so the quarterly time-contract reconciliation can see the reasoning rather than re-derive it.

---

## Research pass — one line of evidence per score

Anchors: [[Scoring Rubric]].

- **Revenue ROI — 2.** Anchor 2 exactly: *"indirect support only — better collateral, easier future pitch."* The chosen success measure is **reach**, not pursuit citation, and the positioning is a deliberately *passive* capability hint with no direct commercial mechanism. No named pursuit was identified as waiting on this.
- **Strategic Alignment — 4.** Advances a named frontier workstream ([[Frontier Radar]]) and inherits its 48h cadence — anchor 4. **Not 5:** it does not produce the charter's defined Day-Zero note, which requires an eval-backed verdict on client-shaped workloads, and no reusable pattern has yet been committed for S8 consumption. Becomes a 5 if the agent chain is documented and handed to the agent-coworker pipeline.
- **Client Impact — 3.** Publicly visible under the Searce brand, and treated as brand-facing enough to require external sign-off — but no client commitment or must-win moment is attached. *Scored against a known anchor gap: the 1–5 anchors are client-shaped and do not cover public/brand visibility with no client behind it. Second entry to hit this.*
- **Urgency — 2.** No named external date for **building** this. The 48h Day-Zero cadence is standing pressure on the output once live, not a deadline for the build. The anchor caps undated items at 2.
- **Culture — 4.** Builds agent-chain orchestration, voice-spec design, automated verification design and a review discipline, across more than one person — anchor 4. Becomes 5 only if the chain is packaged as an asset other squads pull from; that is a commitment, not an observation.
- **Complexity — 4.** Not because the chain is hard: five subagents, a retry loop, a brief schema and two spec files are days of work inside Claude Code. It is 4 because **two things sit outside the chain and are unbounded** — getting a brand voice accepted by an external reviewer, and calibrating the *claim-strength* check, which is a judgement rather than a match — plus a genuine external human dependency, which is anchor 4's stated condition. Note what this score is **not** carrying: the eval integration, the "is this major?" classifier, the platform APIs and the infrastructure were all removed from v1 by the decisions above.

**Overall = 1.90.** Band 1.5–2.5: *"weak, or valuable-but-expensive — ask what would make it cheaper."*

### The rubric's question, answered honestly: cheaper barely helps

Running the descope the rubric prescribes — one voice instead of two, long form only, drop the claim-strength check, reviewer gets the piece by email:

- Complexity 4 → 3 (**+0.25**)
- Culture 4 → 3, since fewer capabilities get built (**−0.15**)
- **Net: 1.90 → 2.00.**

**Complexity is not what is holding this down. Revenue ROI is.** At ROI 3 it scores 2.20; at ROI 4, 2.50. So the useful question is not *"how do we make this cheaper"* — it is *"can anyone name a live pursuit this helps?"*

If nobody can, that is a legitimate answer and the score is correct: this is a brand bet competing for time against client-facing work, and it should be sequenced as one. Recording that plainly is more useful than descoping a system whose cost was never the problem.

---

## Open questions

- **Does a pre-2025 Medium integration token exist inside Searce?** Medium closed its API to new integrations on 1 Jan 2025 and issues no new tokens; existing ones still work. If none exists, the Medium leg is manual-paste permanently, or the long-form target changes. Affects only the publish leg — the chain is unaffected either way.
- **Expected volume per week was not settled.** Read as low (1–5) for v1, which is what makes manual paste and per-piece human review viable. With an external reviewer now in the loop, **the reviewer is the bottleneck, not the pasting** — past roughly five a week the review queue breaks first.
- **Get the reviewer's turnaround in writing.** It is committed verbally. Verbal turnaround agreements decay through busy weeks, invisibly, until a release is missed. Record review latency per piece from day one so the conversation has data behind it.
- **No cost ceiling was set** — judged not worth designing around, which is defensible at low volume where human time dominates. An alert threshold is still worth setting: without a number nothing triggers a look, and agent-chain cost grows through volume or a retry loop rather than through anyone's decision.
- **Untrusted-input risk is inherent to this design.** The chain ingests third-party web content by design, so a vendor page or post can carry text aimed at the research or writer subagent. Mitigations are cheap and belong in the build explicitly: fetched content is treated as data and never as instructions, the research subagent holds no credentials, and a human approves every publish. The last of those is already chosen.
- **Rubric, for the next recalibration:** Client Impact needs an anchor for public/brand visibility with no client attached — second entry to hit that gap. Urgency needs a stated position on standing SLAs versus one-off dates.
- **The board is now stale in two places.** The `POC producer (far future)` node has been retracted, and the `RSS Alert` node does no work under a Claude-Code-resident, human-triggered v1.
