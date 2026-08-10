# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repository.

**This repo is both an Obsidian vault and a Claude working directory.** Humans edit it in Obsidian; Claude edits it as files. Both are first-class. Anything written here must render correctly in Obsidian *and* survive being edited by an agent.

If you cloned this from GitHub: this file is the entire context handoff. Read it fully before touching anything. Setup steps live in `S0/Internal Builds/Pipeline Tracker/Publishing.md`.

---

## 1 · The intake flow — the most important thing here

The Pipeline Tracker turns verbal directives from the CEO ("**Executive Intake**") into a scored, ranked queue. The division of labour is deliberate and asymmetric:

| Step | Who |
|---|---|
| Capture the **verbatim** — the exact words said | **The human.** Same business day. |
| Everything else | **Claude.** |

**"Everything else" means:** the `interpreted` requirement, the research pass, one line of evidence per dimension, all six 1–5 scores, a proposed `slot`, and `status: Scored`.

Do not ask the human to fill scores. That is your job. They supply the raw ask and the commercial context you cannot see.

### How to score an ask

Use `/score-ask` (see `.claude/commands/`), or follow it manually:

1. **Read** `S0/Internal Builds/Pipeline Tracker/Scoring Rubric.md`. The 1–5 anchors are binding, not suggestions. Cap Urgency at 2 when no external date exists — this anchor exists because Urgency inflates fastest.
2. **Research** before scoring. You may consult:
   - **public web** — feasibility, API limits/pricing, whether a thing is a solved problem (drives Complexity)
   - **this vault** — `S0/S0 Charter.md`, prior intake entries, `S0/Brainstorms/*.canvas` (drives Strategic Alignment)
   - **HubSpot/CRM MCP when connected** — named pursuits and renewals (drives Revenue ROI)
3. **Ask the human** for anything commercial you cannot verify — whether a live pursuit depends on the ask, budget qualifiers, client names. **Never guess at deal context.** An unresearched Revenue ROI defaults to 2, and defaulting silently is worse than asking.
4. **Write one line of evidence per score** in the note body. A score without evidence is not defensible in front of the CEO, which is the only bar that matters.
5. **Propose the slot** (`Now` / `Next` / `Blocked`) with reasoning. The human overrides freely — they can see capacity, you cannot.
6. **Set `status: Scored`.**

### ⚠️ Scoring publishes immediately

`status: Scored` puts the row on a **leadership-visible website within minutes** (see §4). There is no human review gate — that is the operator's deliberate choice. Consequences you must respect:

- Never invent evidence to justify a score. The evidence line is the audit trail.
- Score Complexity honestly. Deflating it to make a favoured ask rank higher is the one move that destroys the instrument.
- If you are uncertain enough that a wrong score would mislead leadership, **stop and ask** rather than publishing a guess.

### Never split value from cost

`Overall` is computed by the tracker, never typed. Five dimensions measure value; **Complexity subtracts**. Resource availability is deliberately *not* in the formula — it drives the slot instead. Score once, re-sequence often.

---

## 2 · Confidentiality

- **Never write the string "HMP" into any file.** It is conversational shorthand for verbal CEO directives. In documents always write **"Executive Intake"**.
- `S0/Benchmark Discipline/` is marked `visibility: internal-only`. The charter forbids publishing benchmark data externally. Never surface it in client-facing or public output.
- Intake entries contain client names, revenue judgements, verbatim executive quotes, and per-colleague Culture scores. Treat every one as commercially confidential. The published site is access-controlled for this reason — never suggest removing that gate.

---

## 3 · Obsidian constraints (these break silently)

- **Only `mermaid-flow` is installed as a community plugin.** No Dataview, no Templater. Never write ```` ```dataview ```` blocks or `<% tp.* %>` — they render as dead text. Plain markdown, YAML frontmatter, tags and `[[wikilinks]]` only. Mermaid works (core).
- **Wikilinks resolve by basename, vault-wide.** Never create two notes with the same filename, and never name a folder-landing note `README.md`. Link `.base` files *with* the extension: `[[Priority Ranking.base]]`; embed with `![[Priority Ranking.base]]`.
- **A `.base` file is a query, not a table.** It stores filters, formulas, columns and views — zero rows. Deleting notes empties the table without damaging the base. Never "fix" an empty table by editing the base.
- **`.canvas` files are strict JSON.** `{"nodes":[…],"edges":[…]}`; nodes need `id`/`type`/`x`/`y`/`width`/`height`, edges need `id`/`fromNode`/`fromSide`/`toNode`/`toSide`. Malformed JSON opens blank with no error — validate with `ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' file.canvas` and confirm every edge references a real node id. Obsidian reflows positions when the user edits; treat that as intentional.
- **Score fields must be unquoted numbers.** `roi: 2`, never `roi: "2"`. A quoted value is a string, fails the numeric check, and the row silently never scores.
- Templates live in `_Templates/` and are inserted via **Templates: Insert template**. `{{date}}` auto-fills. `Intake/` holds data only — no templates, no examples.

---

## 4 · The publish pipeline

```
Obsidian edit → Obsidian Git auto-commit (~5 min) → GitHub → Actions: verify → render → Cloudflare Pages (behind Access)
```

- **The only executable code is `.tools/render-tracker.rb`.** Ruby, no gems.
- **It must stay Ruby 2.6-compatible** — macOS system Ruby has no `filter_map` and no endless method definitions (`def f(x) = …`). PyYAML is *not* installed, so use Ruby for YAML work, never Python.
- **Run `ruby .tools/render-tracker.rb --check` after touching the renderer or the weights.** It must print `OK`. CI runs the same check and refuses to deploy if it fails — a stale ranking beats a wrong one.
- **Weights are parsed out of `Priority Ranking.base`**, never hardcoded in the renderer. This is deliberate: two implementations of one ranking would eventually disagree about what is #1. Never hardcode weights to "simplify".
- **The self-check asserts a fixture, not vault data.** An earlier version compared a real note's total to a constant, so every legitimate re-score failed CI. Never assert on live note values.
- Deletions propagate — every run is a full rebuild and full-directory upload.
- `.gitignore` excludes `.obsidian/workspace.json` deliberately: it is rewritten on every pane switch and would trigger a deploy each time.

---

## 5 · Repo facts

- Repo root **is** the vault root. There is no build or test tooling for the notes themselves.
- The **Obsidian Git plugin auto-commits on an interval.** Expect commits you did not author; a clean tree does not mean nothing changed. Do not assume you are the only writer.
- Pushes pass a corporate `pre-push` hook at `/opt/ci-git/` that allowlists destinations by URL. If a push is rejected with *"Not pushing to Searce Gitlab or CSR"*, the remote is not approved — **escalate to the hook's owner; never bypass it with `--no-verify` or by editing the hook.**
- `S0/` is the only squad with content. Add sibling `S{n}/` folders at the vault root for new squads; never nest them under `S0`.

## 6 · Squad members: you are not the only operator

Several people clone this repo and run Claude against it. Therefore:

- **Never rewrite another entry's scores without being asked.** Propose changes in conversation.
- **Pull before you work** (`git pull`) — another operator's entries may be newer than your clone.
- Keep entry filenames descriptive and unique; basename collisions break wikilinks vault-wide.
- **ICU / hot-desk / immediate-build requests require CEO approval before work starts.** Current squad practice, not in the charter text. Recorded in `S0/Field Response Desk/Field Response Desk.md`.
