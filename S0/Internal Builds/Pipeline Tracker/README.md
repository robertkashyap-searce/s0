# Pipeline Tracker — operator guide

Turns verbal directives from leadership into a scored, ranked, published queue. A directive can't be refused; a ranked directive can be sequenced.

**You capture what was said. Claude does the rest.**

For the reasoning behind the model, read `Pipeline Tracker.md`. This file is how to *operate* it.

---

## Daily use

### When you hear an ask — same business day, ~2 minutes

1. In Obsidian, open `S0/Internal Builds/Pipeline Tracker/Intake/`
2. **New note**, name it after the ask (e.g. `Gemini Enterprise eval for Acme`)
3. **Cmd+P** → `Insert template` → **Executive Intake Entry**
4. Fill **`verbatim` only** — the exact words, including the throwaway qualifiers (*"if it's cheap"*, *"eventually"*, *"before the QBR"*). Those are the first thing lost in paraphrase and they drive two of the six scores.
5. Save. Stop.

Leave the scores empty. Leave `status: Awaiting scoring`. It lands in the **Awaiting scoring** view.

### Then hand it to Claude

```
/score-ask <note name>
```

Claude researches feasibility, reads the charter for alignment, **asks you what it can't establish** (commercial stakes, client weight, culture fit), then writes the interpreted requirement, all six scores with one line of evidence each, and a proposed slot.

Answer its questions properly — Revenue ROI is unknowable without you, and an unanswered ROI defaults to 2, which under-ranks commercially valuable work.

### Reading the result

Open `Priority Ranking.base`. **It has two views** — use the switcher at the top-left:

| View | Contains |
|---|---|
| **Priority ranking** | Scored asks, ordered by Overall Score |
| **Awaiting scoring** | Captured but not yet scored, oldest first |

A new ask *will not* appear in Priority ranking. It has no score, so it has no rank. That is not a bug.

---

## The model, briefly

Six dimensions, 1–5. Five measure value; **Complexity subtracts**.

```
Overall = (0.30·ROI + 0.20·Strategic + 0.20·Impact + 0.15·Urgency + 0.15·Culture) − (0.25·Complexity)
```

Range −0.25 to 4.75. Anchors for every number: `Scoring Rubric.md`. **Never type a total** — the tracker computes it, so nobody negotiates their own score.

Capacity is deliberately *not* in the formula. It sets the **slot** (`Now` / `Next` / `Blocked`) instead. Score once, re-sequence often — an ask keeps its score while its slot moves, which is what lets you say "not this week" without saying "not important."

A score under 2.5 is not a rejection. It's the prompt to ask *what would make this cheaper* — usually a thinner slice that serves the same obligation.

---

## First-time setup

You need: **Obsidian**, **git**, **GitHub CLI**, and **Ruby** (macOS ships it).

```bash
git clone <repo-url> && cd <repo>
gh auth login                 # HTTPS, browser
ruby .tools/render-tracker.rb --check   # must print OK
```

Then in Obsidian: **Open folder as vault** → pick the clone.

**Community plugins → Git** → install and enable. Set:

| Setting | Value |
|---|---|
| Auto commit-and-sync interval | your choice — this is the publish cadence |
| Auto commit-and-sync after stopping file edits | **OFF** |
| Pull on startup | ON |

That toggle must be **off**. With it on, the timer only arms in response to edits typed in Obsidian, so changes written by Claude or any other tool never trigger a sync.

Publishing setup (Cloudflare, CI secrets, access control) is already configured for this repo — see `Publishing.md` if you need to change it.

---

## Troubleshooting

Every one of these has actually happened.

| Symptom | Cause | Fix |
|---|---|---|
| Row never gets an Overall Score | Score written as text: `roi: "2"` | Remove the quotes. In Properties, set the six score fields to type **Number**. |
| New ask missing from the table | You're on the **Priority ranking** view | Switch to **Awaiting scoring** |
| Table shows 0 results | No notes match the filter | Normal when `Intake/` is empty. The `.base` holds no rows — never "fix" it by editing the base. |
| Auto-sync never fires | *"after stopping file edits"* is ON | Turn it off (see above) |
| `"gitleaks" Not Opened` popup | Unsigned binary quarantined by macOS | Click **Done**, never *Move to Bin*. Then `sudo xattr -d com.apple.quarantine /opt/ci-git/gitleaks` |
| Push rejected: *"Not pushing to Searce Gitlab or CSR"* | Remote not on the corporate allowlist | Escalate to the owner of `/opt/ci-git/`. **Never** `--no-verify`. |
| Push rejected: *workflow scope* | `gh` token lacks `workflow` | `gh auth refresh -s workflow -h github.com` |
| `gh secret set` stores an empty value | It reads stdin when there's no terminal | Run it in a real terminal, or use the GitHub web UI |
| CI red on "Verify the scoring model" | Weights or arithmetic changed | Run `ruby .tools/render-tracker.rb --check` locally and read the failure. CI refuses to deploy rather than publish a wrong ranking. |

---

## Rules that keep the instrument honest

- **Score Complexity truthfully.** Deflating it to push a favoured ask up the list is the one move that destroys the tool's credibility.
- **Urgency caps at 2 without a named external date.** A standing SLA is pressure, not a deadline.
- **Every score needs one line of evidence.** A score you can't defend in front of the CEO isn't a score.
- **Don't rewrite another operator's scores** without asking them. Several people work in this repo.
- `git pull` before you start. Someone else's entries may be newer than your clone.
