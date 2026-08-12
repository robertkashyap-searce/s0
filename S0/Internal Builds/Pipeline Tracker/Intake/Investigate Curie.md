---
tags:
  - executive-intake
verbatim: "To be researched — purpose, potential application areas for us and our clients and impact it can create, anything we can leverage from here as an idea. https://github.com/curie-eng/curie/blob/main/QUICKSTART.md"
interpreted: A written verdict on the open-source Curie agent-delivery platform — its purpose, where it could apply to us and to client work, the impact it could create, and which of its ideas we can borrow regardless of whether we ever adopt it.
logged: 2026-08-12
logged_by: R. Kashyap
roi: 
strategic: 
impact: 
urgency: 
culture: 
complexity: 
slot: Next
status: Awaiting scoring
---

## Verbatim — what was actually said

> "To be researched
> Purpose, potential application areas for us and our clients and impact it can create, anything we can leverage from here as an idea
> https://github.com/curie-eng/curie/blob/main/QUICKSTART.md"

## Interpreted requirement

A written verdict on the open-source Curie agent-delivery platform — its purpose, where it could apply to us and to client work, the impact it could create, and which of its ideas we can borrow regardless of whether we ever adopt it.

**Qualifiers heard:** *"To be researched"* — the deliverable is a conclusion, not a build. *"anything we can leverage from here as an idea"* — borrowing patterns is explicitly in scope **even if Curie itself is never adopted**, which is the part most likely to be dropped in paraphrase. No date, no named client, no audience stated.

---

## Research pass — what the public record establishes

Verified against the repository and the GitHub API on **2026-08-12**. Facts, not impressions.

### What it is

An open-source, self-hostable delivery platform for Claude-Code-format agents. Apache-2.0, published by **CurieTech AI** (`curietech.ai`), which holds the "Curie" trademark. One CLI (`curie`) drives everything.

The problem it names: *"your agent breaks when it leaves your laptop."* Its single mechanic is a **parity ladder** — the same immutable bundle snapshot climbs three tiers, so an environment difference surfaces as a bug on the way up rather than in production.

| Tier | What actually runs | Needs |
|---|---|---|
| `skill` | Runner container only, no platform in front. Boots straight from the working directory. | Docker |
| `local` | Full platform via Docker Compose — queue → worker → sandbox → reply, plus Postgres, Valkey, Langfuse | Docker + Compose v2 |
| `cluster` | That same platform as a Helm release on Kubernetes | kubectl + Helm |

Included without extra work: **traces** (Langfuse), **evals** (`evals/cases.json`, the same cases at every tier), **budgets**, and **git-driven deploys**. Channel support is **Slack today**; email and Teams are stated as next. Models are configurable — Anthropic by default, OpenRouter, or a local model through Ollama.

### The detail that matters most to us

**The bundle format is the Claude Code plugin format verbatim** — `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, `.mcp.json`, `evals/cases.json`, `AGENTS.md`. That is the format the squad already authors in. A skill written for local use is, structurally, already a deployable unit.

The floor is genuinely low: **one file with one field** (`plugin.json` with a `name`) is a complete valid bundle. Two files and three fields is the smallest *useful* agent. Everything else is optional and validated only when present.

Fast path, verified from QUICKSTART: install the binary, `curie init`, `curie skill up --fake-model`, `curie skill message`. **No credentials and no cluster** for a first reply — the built-in fake model is offline.

### Project maturity — the dominant unknown

| Signal | Value |
|---|---|
| Created | 2026-07-05 (~5 weeks old) |
| Last push | 2026-08-12 (active daily) |
| Stars / forks | 15 / 1 |
| Open issues | 201 |
| Licence / governance | Apache-2.0, single vendor, trademark retained |

**The risk here is adoption and longevity, not technical feasibility.** The engineering reads as deliberate; the ecosystem around it barely exists yet. Any recommendation has to carry that distinction explicitly, because the two get conflated.

### Where it could apply

**To us.** The [[Architecture Hub]] reference-architecture table is empty, and the charter asks that slice for *approved stacks and golden patterns for agentic systems consumed by S8 squads*. "How an agent gets from a laptop to production" is exactly that shape of gap. Separately, [[Internal Builds]] owns agent-coworker patterns — and because Curie's bundle *is* the Claude Code plugin format, an internal agent-coworker could reach a Slack surface without anyone writing a bespoke harness first.

**To clients.** Four properties map onto objections that recur in agent conversations:

1. **Apache-2.0 and self-hostable on the client's own Kubernetes** — answers "we can't route this through a vendor SaaS" without a bespoke build.
2. **Slack-first** — the lowest-friction internal-agent surface in most enterprises, because it is already there.
3. **Model portability** (Anthropic / OpenRouter / Ollama) — a credible exit story on model lock-in, which is a procurement blocker more often than a technical one.
4. **Traces, evals and budgets in the box** — most of the governance checklist an enterprise buyer produces, without a separate observability project.

### Ideas worth borrowing even if we never adopt it

This is the part of the ask that survives a "no" verdict, and the most durable output.

- **The parity ladder itself.** One immutable snapshot, three tiers, environment drift converted into a build-time failure. Portable into any reference architecture we write; it needs no Curie code.
- **Evals as a first-class file inside the bundle, run identically at every tier.** The closest thing in this repo to a habit worth copying wholesale.
- **Progressive-disclosure config.** "One file, one field" valid; everything else optional and validated only when present. A design standard for our own scaffolds.
- **Honest scope language.** The README states plainly that it offers *an environment guarantee, not a behaviour guarantee.* Worth copying into our own architecture docs, where we tend to overclaim by omission.
- **A harness-primer skill shipped inside the bundle** (`using-curie`), so a coding agent can learn to drive the platform it deploys to.
- **Signed-checksum plus optional `cosign` verification on install**, with an env var that makes verification mandatory.

**Boundary worth stating before anyone assumes otherwise:** Curie is a *delivery* platform, not an eval harness. It does not touch [[Benchmark Discipline]]'s mandate, and its eval feature is behaviour-grading for one bundle, not a model-agnostic comparison instrument.

### Caveats that belong in any recommendation

- **`curl … | bash` is the documented install.** For anything client-facing, use the by-hand download-verify-install path instead.
- **Production needs external Postgres and S3-compatible storage** — not included in the parity story.
- **Slack is the only channel today.** Email and Teams are stated intent, not shipped.
- **Environment parity is not behaviour parity**, by the project's own admission.

---

## Scoring — deferred until the questions below are answered

Per [[Scoring Rubric]] and the intake rule: **research first, then ask, then score.** Research settles feasibility and cost; it cannot settle commercial or political weight. Those answers are below, not in the repository.

What research *has* fixed, on the record, so the scores land fast once answers arrive:

- **Urgency** — no external date anywhere in the ask. The anchor caps an undated item at **2** unless a date exists that has not been said.
- **Complexity** — depends entirely on which deliverable is wanted, and the gap is wide. A desk-style written verdict, plus a `skill`-tier hands-on run, is **hours to ~2 days**: known path, no credentials needed for first contact, and we already author in the required format. A `cluster`-tier pilot against a real workload is a different order of work — external dependencies, a Kubernetes environment, Postgres and S3. **These are not the same score, so the scope question is not a formality.**
- **Strategic Alignment** — the candidate anchors are [[Architecture Hub]] and [[Internal Builds]]. **[[Frontier Radar]] fits poorly**: Curie is not a model release, so the 48h Day-Zero mechanic has nothing to trigger on. Which slice this charges to is a decision, not an inference.

## Open questions

Batched deliberately — one reply unblocks all six scores. Each names the score it moves.

1. **Is any live pursuit or client conversation waiting on an answer about self-hosted agent deployment?** → **Revenue ROI.** Unanswered, this defaults to 2 (*indirect support only*), and a silent default is worse than an asked question. If a named opportunity exists, say so; the anchor moves to 4.
2. **Who reads the verdict?** Squad-internal note · all-solvers channel · a named client team · an exec readout. → **Client Impact.** These are 1, 2, 3 and 4 on the anchor table respectively.
3. **Which deliverable — a written verdict, or hands-on?** And if hands-on, which tier is far enough: `skill`, `local`, or `cluster`? → **Complexity**, per the spread above. This also decides whether the output is a [[Field Response Desk]] answer or an [[Architecture Hub]] entry.
4. **Which charter slice does this charge to?** Architecture Hub · Internal Builds · Field Response Desk · frontier 40%. → **Strategic Alignment**, and it sets the cadence anyone should expect.
5. **Is there a date behind this that wasn't said?** → **Urgency.** Without one it is capped at 2, by design.
6. **Is more than one person evaluating, and does a written pattern or teach-in come out of it?** → **Culture.** One person reading a repo is a 2; a documented pattern is a 3; capability in two or more people, or a teach-in, is a 4.

**Slot is a placeholder at `Next`** — override it freely, since capacity is visible to you and not to me.

**One thing to be aware of while this sits here:** the `executive-intake` tag publishes this note from **capture**, not from scoring, so this page — body included — reaches the public leadership-visible site at the next publish cycle with `Awaiting scoring` on it. It has been written to be safe in that state: no client names, no deal context, no benchmark data.
