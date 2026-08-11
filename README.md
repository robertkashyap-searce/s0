# Revelations — the S0 vault

An Obsidian vault and a Claude Code working directory, in one repository. Humans edit it in Obsidian; Claude edits it as files. Both are first-class.

It holds the working memory of **S0** — Searce's zero-indexed R&I squad — and one live instrument built on top of it: the **Pipeline Tracker**, which turns verbal directives from leadership into a scored, ranked, published queue.

---

## Start here

```bash
git clone <repo-url> && cd <repo>
gh auth login                            # HTTPS, browser
ruby .tools/render-tracker.rb --check     # must print OK
```

Then **Obsidian → Open folder as vault →** pick the clone.

Two things to read, in order:

1. **[CLAUDE.md](CLAUDE.md)** — the operating contract. Auto-loaded by Claude Code; read it yourself too, because it encodes constraints that fail silently.
2. **[Pipeline Tracker README](S0/Internal%20Builds/Pipeline%20Tracker/README.md)** — day-to-day operation, setup, troubleshooting.

---

## What's in here

| Path | What it is |
|---|---|
| `S0/S0 Charter.md` | The squad charter, transcribed in full. The canonical source for the time contract, the three quarterly gates, and the success criteria. |
| `S0 — Index.md` | Map of content. Reconciles vocabulary — "POC builds" = charter's "internal builds", "ICU" = "hot desk". |
| `S0/Frontier Radar/` | Day-Zero Release Notes, ≤48h after any major model release. |
| `S0/Benchmark Discipline/` | **Internal only.** The charter forbids publishing benchmark data externally. |
| `S0/Architecture Hub/` | Reference architectures, paved roads, road-deviation notes. |
| `S0/Field Response Desk/` | Same-day eval-grounded positions; also the ICU/hot-desk intake. |
| `S0/Client Engagements/` · `S0/Internal Builds/` | The two 20% delivery slices. |
| `S0/Brainstorms/` | Whiteboard captures as dated `.canvas` files. |
| `_Templates/` | Note templates, inserted via **Templates: Insert template**. |
| `.tools/` | The only executable code — `render-tracker.rb`. Ruby, no gems. |
| `.claude/commands/` | Slash commands. `/score-ask` runs the scoring workflow. |

## How the squad's time is meant to split

From the charter, and the reason the tracker exists at all:

| Share | Slice |
|---|---|
| 40% | **The frontier** — research, builds, white papers, benchmark sweeps. Sacred; urgent work borrows from the other slices. |
| 20% | **Client work** — real, billable delivery. |
| 20% | **Internal builds** — the platforms Searce runs on. |
| 20% | **The hot desk** — must-win demos and escalations. Capped: 20% means 20%. |

Balanced quarterly, not weekly — *"measure the integral, not the derivative."*

---

## The Pipeline Tracker in one minute

**A directive can't be refused. A ranked directive can be sequenced.**

Executive asks arrive verbally at a squad already running a full contract, each sounding like the most important thing said that week. Without an instrument, everything becomes "ASAP", ASAP stops meaning anything, and delivery optimises for volume instead of value.

The division of labour is deliberate:

| Step | Who |
|---|---|
| Capture the **verbatim** — exact words, same business day | **You** |
| Interpretation, research, six scores with evidence, proposed slot | **Claude**, via `/score-ask` |
| Overall Score | **Computed.** Never typed. |
| `Now` / `Next` / `Blocked` | **You** — capacity is yours to see |

Six dimensions, 1–5. Five measure value; Complexity **subtracts**, so a valuable-but-disproportionately-hard ask ranks below an equally valuable cheap one.

Scored entries publish to a read-only web view for leadership who don't open Obsidian: https://robertkashyap-searce.github.io/s0/. Rendering and deployment run in CI — no laptop in the path once a push lands. **The site is public and has no sign-in**, and publishing a note publishes its whole body — so write every intake entry as a document anyone may read. See `Publishing.md`.

Full reasoning: `S0/Internal Builds/Pipeline Tracker/Pipeline Tracker.md`. Weights and anchors: `Scoring Rubric.md`. Publishing: `Publishing.md`.

---

## Conventions worth knowing before you edit

- **No Dataview, no Templater.** Only `mermaid-flow` is installed. Those blocks render as dead text. Plain markdown, YAML frontmatter, tags, `[[wikilinks]]`. Mermaid works.
- **Wikilinks resolve by basename, vault-wide.** Never duplicate a filename. `README.md` is the deliberate exception (GitHub renders one per directory) — so never write `[[README]]`; use a path.
- **Score fields must be unquoted numbers.** `roi: 2`, never `roi: "2"` — a quoted value is a string and the row silently never scores.
- **A `.base` file is a query, not a table.** It stores filters, formulas and views; zero rows. An empty table means no notes match, not a broken base.
- **`.tools/render-tracker.rb` must stay Ruby 2.6-compatible.** macOS system Ruby has no `filter_map` and no endless method definitions. PyYAML isn't installed — use Ruby for YAML, not Python.
- **Never bypass the corporate `pre-push` hook.** If a push is refused as an unapproved destination, escalate to the owner of `/opt/ci-git/`.
- **Never write the internal shorthand for CEO directives into a file.** In documents it's **"Executive Intake"**.
- **ICU / immediate-build requests need CEO approval before work starts.** Squad practice, not in the charter text.

## Multiple operators

Several people clone this repo and run Claude against it. `git pull` before you start, don't rewrite someone else's scores without asking, and keep filenames unique.
