---
tags: [s0, pipeline-tracker, publishing]
parent: "[[Pipeline Tracker]]"
visibility: internal-only
---

# Publishing the tracker

A read-only web view of [[Priority Ranking.base]] for leadership who don't open Obsidian. Updates automatically when intake notes change.

> [!warning] The link is the perimeter
> Rows carry client names, revenue judgments, verbatim executive quotes, and per-colleague Culture scores. **Deploy behind Cloudflare Access before the first real entry exists.** A Pages URL with no Access policy is public to anyone who guesses or is forwarded it — "read-only" says nothing about *who may read*.

## Why not Obsidian Publish

Asked and answered: **Obsidian Publish does not render Bases.** Obsidian staff, 10 Oct 2025 — *"Not yet."* Even when it lands, Publish's only access control is a single site-wide password, which is not a perimeter for this content.

## How it works

```
Intake/*.md (frontmatter)  ─┐
                            ├─→ render-tracker.rb ─→ .tracker-site/index.html ─→ Cloudflare Pages
Priority Ranking.base ──────┘        (weights)                                    (behind Access)
     ↑ single source of truth for the weights
```

Three properties worth knowing:

- **No formula drift.** The renderer parses the weights *out of* the `.base` formula rather than hardcoding them. Change a weight in Obsidian and the site follows. Two implementations of the ranking would eventually disagree about what's #1; this design makes that impossible.
- **Deletions propagate.** Every run is a full rebuild and a full-directory upload. A retracted directive disappears from the site instead of quietly living on — the standard failure of sync-based publishers.
- **It refuses to ship bad numbers.** `publish.sh` runs the self-check first and aborts the deploy if the weights or the reference row don't verify. A stale ranking beats a wrong one.

## Tooling

Lives in `Documents/Obsidian/tools/` — outside the vault, because Obsidian has `showUnsupportedFiles` on and `.rb`/`.sh` inside `Revelations/` would clutter the file explorer.

| File | Role |
|---|---|
| `render-tracker.rb` | Reads the base + intake notes, emits self-contained HTML. Ruby 2.6-compatible (macOS system Ruby, no installs). |
| `publish.sh` | Self-check → render → deploy. |
| `com.searce.s0.tracker.plist` | launchd WatchPaths agent. **Not installed** by default. |

## One-time setup

```bash
cd ~/Documents/Obsidian/tools

# 1. Verify locally first — must print "OK"
ruby render-tracker.rb --check
ruby render-tracker.rb && open ../.tracker-site/index.html

# 2. Create the Pages project and deploy once (prompts a browser login)
npx wrangler login
npx wrangler pages project create s0-pipeline-tracker
./publish.sh
```

**3. Add the Access policy — do not skip.** Cloudflare dashboard → Zero Trust → Access → Applications → *Add self-hosted app*, point it at the Pages domain, and set the policy to **Allow → Emails** listing each named reader. One-time-PIN email is enough; no IdP required. Free for up to 50 users.

Confirm it worked by opening the URL in a private window: you should be challenged, not shown the table.

## Turn on auto-publish

```bash
cp com.searce.s0.tracker.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.searce.s0.tracker.plist
```

Republishes within ~2 min of any change to `Intake/` or the `.base` (throttled so a burst of edits is one deploy). Log: `.tracker-site/publish.log`.

To pause: `launchctl unload ~/Library/LaunchAgents/com.searce.s0.tracker.plist`.

## Known limits

- **Laptop-bound.** Publishing runs on this Mac; asleep or offline means the site is stale, not broken. Acceptable while the squad is small — move to a scheduled cloud job only if staleness starts costing something.
- **Additive tag scope.** The base collects any note tagged `executive-intake`. The renderer additionally reads only from `Intake/`, so a stray tag elsewhere in the vault reaches the Obsidian view but not the website.
- **No redaction layer.** Everything scored is shown, by design, because the audience is leadership. **If the audience ever widens to clients or cross-squad readers, this needs a redaction pass first** — a client reading their own ROI score of 2 is an incident, not a transparency win.
