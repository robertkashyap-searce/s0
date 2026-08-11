---
tags: [s0, pipeline-tracker, publishing]
parent: "[[Pipeline Tracker]]"
visibility: internal-only
---

# Publishing the tracker

A live, read-only web view of [[Priority Ranking.base]] for leadership and S0 members who don't open Obsidian. Hosted on **GitHub Pages at https://robertkashyap-searce.github.io/s0/**. Rendered and deployed by CI — **no laptop, no local server, no connection to this vault required for the site to stay up or to update.**

**It is a small site, not one page.** `index.html` carries the three tables; every ask name links to a full page for that entry, and [[Scoring Rubric]] and [[Pipeline Tracker]] publish as reference pages so a score is legible to whoever lands on it. GitHub Pages serves a whole directory, so this needed no infrastructure change — only more files in `.tracker-site/`.

**The published set is an allowlist, deliberately — never a link crawl.** It is `Intake/*.md` plus the two reference docs, and nothing else. A crawl would follow `[[S0 Charter]]` and `[[Benchmark Discipline]]` and publish what the charter forbids. A wikilink pointing outside the allowlist renders as plain text rather than a link, so the boundary holds even if someone adds a new `[[…]]` to a note.

**With no gate on the site, that allowlist is the only thing standing between an `internal-only` note and the open web.** Widening it is a publication decision, not a rendering tweak.

> [!important] The site is public, by decision of the repo owner
> There is **no authentication gate of any kind** — no sign-in, no reader
> allowlist, no IdP. Anyone who has the URL, or arrives at it any other way, reads every
> published page in full: the ranking tables, and every intake note body behind
> them.
>
> The renderer emits `<meta name="robots" content="noindex,nofollow">`, which asks
> search engines not to index the pages. **That is not access control.** It
> changes how the site is *discovered*, not who may read it.
>
> The consequence is for what gets written, not for the hosting: **an intake note
> is a public document from the moment the `executive-intake` tag lands — capture publishes it; scoring only moves which table it appears in. The Awaiting-scoring table prints the `verbatim` on the index.** See the
> confidentiality callout below before typing a verbatim.

> [!warning] The note body is the disclosure surface
> Entries carry client names, revenue judgments, verbatim executive quotes, and per-colleague Culture scores, and **publishing an entry publishes its whole body — every word, verbatim quote included.** With no gate in front of the site, "read-only" now means *anyone may read, nobody may edit*. Write each entry as if a client, a competitor or a journalist will read it, because nothing stops them. There is no per-field redaction and no partial publish: if a detail cannot survive being read by anyone, it does not belong in the note body.

## Why not Obsidian Publish

Asked and answered: **Obsidian Publish does not render Bases.** Obsidian staff, 10 Oct 2025 — *"Not yet."* The tables are the whole point of the site, so a publisher that cannot draw them is not a candidate.

## Architecture

```
Obsidian edit  →  Obsidian Git auto-push  →  GitHub repo
                        (any device)           (source of truth)
                                                       ↓
                                           GitHub Actions: verify → render
                                                       ↓
                                       GitHub Pages, public, no gate  →  readers
```

The site builds from GitHub, not from a machine. Once a push lands, the Mac can sleep — the deploy completes in the cloud and GitHub Pages serves the result 24/7. One vendor, one set of credentials: the deploy uses the workflow's own `GITHUB_TOKEN`, so there are no third-party API tokens to store or rotate.

**The one honest caveat:** some device has to get your edit into GitHub. Obsidian Git does it automatically on an interval, and works on Obsidian mobile too — so it isn't tied to *one laptop*, but it isn't literally device-free. Anything claiming otherwise is hiding the push.

Four properties worth knowing:

- **No formula drift.** The renderer parses the weights *out of* the `.base` formula instead of hardcoding them. Change a weight in Obsidian and the site follows. Two implementations of one ranking would eventually disagree about what's #1; this makes that impossible.
- **Deletions propagate.** Every run is a full rebuild and a full-directory upload, so a retracted directive disappears instead of quietly living on — the standard failure of sync-based publishers.
- **It refuses to ship bad numbers.** CI runs `--check` first and fails the deploy if the weights or the reference row don't verify. A stale ranking beats a wrong one.
- **Bursts collapse to one deploy.** The workflow runs in the dedicated `pages` concurrency group. A newer run supersedes an older *pending* one, so a flurry of edits publishes once from the newest state — but a deploy already in flight is allowed to finish rather than being cancelled, because cancelling a Pages deployment mid-flight can leave the environment stuck.

## Files

| File | Role |
|---|---|
| `.tools/render-tracker.rb` | Renders base + intake notes → a small static site. Ruby 2.6-compatible, no gems. |
| `.tools/markdown.rb` | Hand-rolled Markdown→HTML for the note subset the vault uses. No markdown gem is installed here; content is escaped before any tag is emitted. |
| `.github/workflows/publish-tracker.yml` | Verify → render → deploy, on every relevant push. |
| `.gitignore` | Excludes `workspace.json` (rewritten constantly — would deploy on every pane switch) and build output. |

`.tools/` and `.github/` are dot-folders: Obsidian hides them, git tracks them.

## One-time setup

**1. Create the private repo and push.** `gh` isn't installed here, so either install it (`brew install gh`) or create the repo in the GitHub UI. The vault is already a git repo with an initial commit.

```bash
cd ~/Documents/Obsidian/Revelations
git remote add origin git@github.com:<org-or-you>/s0-vault.git
git push -u origin main
```

**Private repo, not public** — it contains executive quotes and client names. Repo visibility and site visibility are separate settings: the repo being private does not gate the published site, and the site being public does not expose the repo.

**2. Enable GitHub Pages, sourced from the workflow.** In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions.** That is the whole hosting setup — there is no project to create, no CLI to install, and **no repo secrets to add**; the deploy authenticates with the workflow's built-in `GITHUB_TOKEN`.

The workflow needs the two permissions Pages deployment requires (`pages: write`, `id-token: write`); they are declared in `publish-tracker.yml`, so this is only worth checking if a deploy fails with a permissions error.

**3. Note the URL and who can reach it.** The site publishes to https://robertkashyap-searce.github.io/s0/. It is public — see the callouts at the top of this note before the first real entry exists.

Verify in a private window: you should see the tables immediately, with no sign-in step. Being challenged would mean the URL is not the Pages site.

**4. Turn on auto-push.** Obsidian → Settings → Community plugins → browse → **Git** → enable. Set *auto commit-and-sync* to an interval that matches how fast leadership needs to see changes (5–10 min is plenty).

Then trigger a first run: Actions tab → *Publish Pipeline Tracker* → Run workflow.

## Known limits

- **Push needs a device.** Covered above. The site staying *live* needs nothing; the site staying *current* needs a device that has synced.
- **The whole vault is on GitHub.** By deliberate choice. Note that [[Benchmark Discipline]] is marked internal-only and the charter forbids external publication of benchmark data — a private repo is not "published," but it is a third-party service holding it. Revisit if that reading ever tightens.
- **No redaction layer, and the whole note body publishes — not just the columns.** Everything in a scored entry is shown. Note what changed when per-entry pages arrived: previously a scored row exposed only frontmatter-derived numbers, and the **verbatim executive quote appeared nowhere** for scored asks. Now every word of an entry is on the site — the verbatim, the interpreted requirement, recorded objections, contestable scores, and per-colleague Culture reasoning. Publishing is all-or-nothing per note: the allowlist decides *which* notes go up, never which parts of one. Combined with a site that has no gate, **the intake note is the disclosure surface: assume anything written in an entry is readable by anyone.** A client reading their own ROI score of 2 is an incident, not a transparency win — so the redaction pass has to happen in the note body, at writing time, because there is no layer downstream to do it.
- **Culture scores are visible to the people they describe, and to everyone else.** Per-colleague reasoning about a named colleague publishes verbatim. That needs to be a deliberate yes from the person writing it, not a surprise to the person named.
