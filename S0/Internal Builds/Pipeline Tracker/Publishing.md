---
tags: [s0, pipeline-tracker, publishing]
parent: "[[Pipeline Tracker]]"
visibility: internal-only
---

# Publishing the tracker

A live, read-only web view of [[Priority Ranking.base]] for leadership and S0 members who don't open Obsidian. Rendered and deployed by CI — **no laptop, no local server, no connection to this vault required for the site to stay up or to update.**

> [!warning] The link is the perimeter
> Rows carry client names, revenue judgments, verbatim executive quotes, and per-colleague Culture scores. **Add the Cloudflare Access policy before the first real entry exists.** A Pages URL with no Access policy is readable by anyone who is forwarded it — "read-only" says nothing about *who may read*.

## Why not Obsidian Publish

Asked and answered: **Obsidian Publish does not render Bases.** Obsidian staff, 10 Oct 2025 — *"Not yet."* And its only access control is one site-wide password, which is not a perimeter for this content.

## Architecture

```
Obsidian edit  →  Obsidian Git auto-push  →  private GitHub repo
                        (any device)              (source of truth)
                                                        ↓
                                            GitHub Actions: verify → render
                                                        ↓
                                        Cloudflare Pages, behind Access  →  readers
```

The site builds from GitHub, not from a machine. Once a push lands, the Mac can sleep — the deploy completes in the cloud and the URL serves from Cloudflare's edge 24/7.

**The one honest caveat:** some device has to get your edit into GitHub. Obsidian Git does it automatically on an interval, and works on Obsidian mobile too — so it isn't tied to *one laptop*, but it isn't literally device-free. Anything claiming otherwise is hiding the push.

Four properties worth knowing:

- **No formula drift.** The renderer parses the weights *out of* the `.base` formula instead of hardcoding them. Change a weight in Obsidian and the site follows. Two implementations of one ranking would eventually disagree about what's #1; this makes that impossible.
- **Deletions propagate.** Every run is a full rebuild and a full-directory upload, so a retracted directive disappears instead of quietly living on — the standard failure of sync-based publishers.
- **It refuses to ship bad numbers.** CI runs `--check` first and fails the deploy if the weights or the reference row don't verify. A stale ranking beats a wrong one.
- **Bursts deploy once.** Concurrency is capped with `cancel-in-progress`, so a flurry of edits produces one deploy from the newest state.

## Files

| File | Role |
|---|---|
| `.tools/render-tracker.rb` | Renders base + intake notes → self-contained HTML. Ruby 2.6-compatible, no gems. |
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

**Private repo, not public** — it contains executive quotes and client names.

**2. Cloudflare: create the Pages project once.**

```bash
npx wrangler login
npx wrangler pages project create s0-pipeline-tracker
```

**3. Add two GitHub repo secrets** (Settings → Secrets and variables → Actions):

| Secret | Where to get it |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare dashboard → My Profile → API Tokens → *Edit Cloudflare Workers* template |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare dashboard sidebar, or `npx wrangler whoami` |

**4. Add the Access policy — do not skip.** Cloudflare dashboard → Zero Trust → Access → Applications → *Add self-hosted app*, point it at the Pages domain, policy **Allow → Emails** (or an email-domain rule for the squad). One-time-PIN email is enough; no IdP needed. Free up to 50 users.

Verify in a private window: you should be challenged, not shown the table.

**5. Turn on auto-push.** Obsidian → Settings → Community plugins → browse → **Git** → enable. Set *auto commit-and-sync* to an interval that matches how fast leadership needs to see changes (5–10 min is plenty).

Then trigger a first run: Actions tab → *Publish Pipeline Tracker* → Run workflow.

## Known limits

- **Push needs a device.** Covered above. The site staying *live* needs nothing; the site staying *current* needs a device that has synced.
- **The whole vault is on GitHub.** By deliberate choice. Note that [[Benchmark Discipline]] is marked internal-only and the charter forbids external publication of benchmark data — a private repo is not "published," but it is a third-party service holding it. Revisit if that reading ever tightens.
- **No redaction layer.** Everything scored is shown, because the audience is internal. **If readers ever widen to clients, this needs a redaction pass first** — a client reading their own ROI score of 2 is an incident, not a transparency win.
- **Culture scores are visible to the people they describe.** Fine among S0 members if that's intended; it should be a deliberate yes, not a surprise.
