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

### Rule: ask before you conclude

**Never settle a score or a rationale from your own reasoning alone.** Research first, then ask the human the questions your research could not answer — and wait for the answers before writing any score.

- Batch questions into one message. Don't drip them.
- Say which score each answer moves, so the human knows what's at stake in replying.
- The human is the **primary** source for anything commercial, political, or cultural — not a fallback when tooling is missing. They know what leadership actually meant, which pursuits are live, and how the squad feels about the work. No integration answers those better than a person who was in the room.
- Research is for what a person *shouldn't* have to look up: API pricing, rate limits, whether a hard problem is already solved. Do that yourself; don't outsource it to them.

### How to score an ask

Use `/score-ask` (see `.claude/commands/`), or follow it manually:

1. **Read** `S0/Internal Builds/Pipeline Tracker/Scoring Rubric.md`. The 1–5 anchors are binding, not suggestions. Cap Urgency at 2 when no external date exists — this anchor exists because Urgency inflates fastest.
2. **Research** what you can establish yourself:
   - **public web** — feasibility, API limits and pricing, third-party dependencies, whether the hard part is a solved problem (drives Complexity)
   - **this vault** — `S0/S0 Charter.md`, prior intake entries, `S0/Brainstorms/*.canvas` (drives Strategic Alignment). An ask often already has a design sketch on a canvas; look before you estimate.
3. **Then ask the human everything else.** Revenue ROI, client stakes, political weight, culture fit — these live in a person's head, not in a system. Ask directly rather than reaching for a CRM integration; the answers are better and arrive faster. **Never guess at deal context.** An unasked Revenue ROI defaults to 2, and defaulting silently is worse than asking.
4. **Write one line of evidence per score** in the note body. A score without evidence is not defensible in front of the CEO, which is the only bar that matters.
5. **Propose the slot** (`Now` / `Next` / `Blocked`) with reasoning. The human overrides freely — they can see capacity, you cannot.
6. **Set `status: Scored`.**

### Publishing is periodic, and unattended

The `executive-intake` tag puts the note on a leadership-visible website (see §4) at the **next publish cycle** — from **capture**, not from scoring. `status` only selects which table it lands in: `Awaiting scoring` still publishes the note page **and prints the `verbatim` on the index**; `Scored` moves it into the ranking; `Shipped`/`Done` into the Shipped table. **There is no private drafting window.** The operator sets that interval on Obsidian Git's commit-and-sync timer — it may be minutes, it may be eight hours. **Never assume a value; read the plugin setting if it matters to what you're doing.**

So there is a delay, but there is no *reviewer*. Nobody is obliged to read your scores before leadership does. Consequences you must respect:

- Never invent evidence to justify a score. The evidence line is the audit trail.
- Score Complexity honestly. Deflating it to make a favoured ask rank higher is the one move that destroys the instrument.
- If you are uncertain enough that a wrong score would mislead leadership, **stop and ask** rather than publishing a guess.

### Never split value from cost

`Overall` is computed by the tracker, never typed. Five dimensions measure value; **Complexity subtracts**. Resource availability is deliberately *not* in the formula — it drives the slot instead. Score once, re-sequence often.

---

## 2 · Confidentiality

- **Never write the string "HMP" into any file.** It is conversational shorthand for verbal CEO directives. In documents always write **"Executive Intake"**.
- `S0/Benchmark Discipline/` is marked `visibility: internal-only`. The charter forbids publishing benchmark data externally. Never surface it in client-facing or public output.
- Intake entries contain client names, revenue judgements, verbatim executive quotes, and per-colleague Culture scores. Treat every one as commercially confidential.
- **The published site is public. There is no authentication gate, by decision of the repo owner** — so an intake note is a public document from the moment it is published. This does not loosen the rule above, it tightens it: what protects confidential material is what you decline to write into a published note, because nothing downstream redacts it. Write every entry to be safe in front of the named client.

---

## 3 · Obsidian constraints (these break silently)

- **Only `mermaid-flow` is installed as a community plugin.** No Dataview, no Templater. Never write ```` ```dataview ```` blocks or `<% tp.* %>` — they render as dead text. Plain markdown, YAML frontmatter, tags and `[[wikilinks]]` only. Mermaid works (core).
- **Wikilinks resolve by basename, vault-wide.** Never create two notes with the same filename. Link `.base` files *with* the extension: `[[Priority Ranking.base]]`; embed with `![[Priority Ranking.base]]`.
- **`README.md` is the one deliberate exception.** GitHub renders a `README.md` per directory, so this repo has several — they exist for humans arriving from GitHub. Because their basenames collide, **never write `[[README]]`**; reference a README by its path instead.
- **A `.base` file is a query, not a table.** It stores filters, formulas, columns and views — zero rows. Deleting notes empties the table without damaging the base. Never "fix" an empty table by editing the base.
- **`.canvas` files are strict JSON.** `{"nodes":[…],"edges":[…]}`; nodes need `id`/`type`/`x`/`y`/`width`/`height`, edges need `id`/`fromNode`/`fromSide`/`toNode`/`toSide`. Malformed JSON opens blank with no error — validate with `ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' file.canvas` and confirm every edge references a real node id. Obsidian reflows positions when the user edits; treat that as intentional.
- **Score fields must be unquoted numbers.** `roi: 2`, never `roi: "2"`. A quoted value is a string, not a number. This used to unscore the row in silence; `--check` now rejects it by name and fails the build, so the deploy stops instead of publishing a wrong ranking.
- **Tags may be a list or a bare scalar.** `tags: executive-intake` and a `- ` block sequence both work. Don't "fix" one into the other.
- Templates live in `_Templates/` and are inserted via **Templates: Insert template**. `{{date}}` auto-fills. `Intake/` holds data only — no templates, no examples.

---

## 4 · The publish pipeline

```
Obsidian edit → Obsidian Git auto commit-and-sync (operator-set interval)
              → GitHub → Actions: verify → render → GitHub Pages (public, no gate)
```

The site is https://robertkashyap-searce.github.io/s0/ — public, and served entirely by GitHub. Nothing else is in the path.

- **The only executable code is `.tools/` — `render-tracker.rb` and `markdown.rb`.** Ruby, no gems. `markdown.rb` is a hand-rolled Markdown→HTML renderer for the subset the notes actually use; no markdown gem is installed, and adding one in CI but not locally would give the two runners different output.
- **It must stay Ruby 2.6-compatible** — macOS system Ruby has no `filter_map` and no endless method definitions (`def f(x) = …`). PyYAML is *not* installed, so use Ruby for YAML work, never Python.
- **Run `ruby .tools/render-tracker.rb --check` after touching the renderer or the weights.** It must print `OK`. CI runs the same check and refuses to deploy if it fails — a stale ranking beats a wrong one.
- **Weights are parsed out of `Priority Ranking.base`**, never hardcoded in the renderer for the render itself — but `--check` deliberately **pins** the six coefficients in `expect`, so a reweight must update that table in the same commit or CI refuses to deploy. This is deliberate: two implementations of one ranking would eventually disagree about what is #1. Never hardcode weights to "simplify".
- **The self-check asserts a fixture, not vault data.** An earlier version compared a real note's total to a constant, so every legitimate re-score failed CI. Never assert on live note values.
- Deletions propagate — every run is a full rebuild and full-directory upload, and the renderer clears `.tracker-site/*.html` first so a retracted ask's page cannot survive locally and get re-uploaded.
- **The site is multi-page, and publication is opt-in from the note.** `index.html` holds the three tables; every published note gets its own page. Two gates, both frontmatter tags, both read through `tag_list`:
  - `Intake/*.md` publishes when `tags` includes **`executive-intake`**.
  - A reference doc in the Pipeline Tracker folder publishes when `tags` includes **`publish-to-site`**. Tag it in Obsidian and it appears on the next push; untag it and it stops. **No code change either way** — that is the point, so don't add a hardcoded list back.
  - Not `publish`: `Publishing.md` carries the tag `publishing`, and the two should not be confusable by eye. `Publishing.md` and the READMEs simply don't carry the tag, which is how they stay off the site.
- **Opt-in, never opt-out, and never a link crawl.** A new file in that folder must not publish because someone forgot to exclude it. The glob is folder-scoped, so it cannot reach `[[S0 Charter]]` or `[[Benchmark Discipline]]` whatever is tagged — publishing those is what the charter forbids. A wikilink whose target isn't published renders as plain text, by design.
- **Frontmatter is parsed only when the file opens with a `---` fence.** `README.md` has no frontmatter but uses `---` as a horizontal rule; splitting on it regardless handed body prose to the YAML parser and aborted the entire render. Both loaders go through the `frontmatter` helper — keep it that way.
- **The theme lives in exactly one place.** `CSS` in `render-tracker.rb` is a single constant interpolated by `page()`, which every page type shares — so a new note inherits the whole design with no styling work. It implements the **v0 futurify.ai design system**: two tones (`#faf9f6` paper, `#111110` ink, never pure white or black), **no accent colour and none may be invented**, radius 2px, no shadows, three self-hosted faces from `.tools/fonts/*.woff2`, and the quilt motif inlined as a mask. Colour is spent only on **state** (slot, status) and **data** (the five chart slots marking the scoring dimensions). Light/dark switches via a `data-theme` stamp persisted in `localStorage`; light is also the bare-`:root` default, so pages render correctly before any script runs.
  - The heredoc **interpolates**, so never write `#{` inside it — and never a backslash, because it is unquoted, so a backslash is eaten and silently corrupts the byte while `--check` still prints OK.
  - Fonts are sourced from `.tools/fonts` because it is **tracked**. `.tracker-site/` is gitignored, so fonts placed there pass every local check and 404 in production.
  - `dangling_links` scans every emitted `href`. Anything carrying a URI scheme is skipped; a relative target that isn't a page aborts the render. Never write an exact-match `[href="…"]` selector into the stylesheet.
- **Publishing a note publishes its entire body**, including the verbatim executive quote. Before this, only frontmatter-derived columns were visible for scored rows. There is no per-field redaction — the allowlist chooses which notes publish, never which parts of one. **Assume anything written in an intake note is readable by anyone**; the site has no gate. The renderer's `noindex,nofollow` keeps search engines off, which is not the same as keeping readers out.
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
