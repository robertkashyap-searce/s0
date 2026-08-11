#!/usr/bin/env ruby
# Renders the Pipeline Tracker to a small static site.
#
# Weights are parsed OUT of Priority Ranking.base so the .base file stays the
# single source of truth. Change a weight in Obsidian and the site follows.
# Full rebuild every run, so deletions propagate (an unpublished retraction
# staying live was the top disclosure risk raised in review).
#
# Output is a DIRECTORY, not one file: index.html carries the three tables, and
# every published note gets its own page so the ranking is clickable the way the
# vault is. GitHub Pages deploys a directory (see publish-tracker.yml), so
# multiple interlinked pages need no infrastructure change.
#
# Usage:  ruby render-tracker.rb            # render
#         ruby render-tracker.rb --check    # self-check, renders nothing
#
# Lives in <vault>/.tools/ — a dot-folder, so Obsidian hides it (the vault has
# showUnsupportedFiles enabled) while git still tracks it, which is what lets
# GitHub Actions run this in CI with no laptop involved.

require 'yaml'
require 'cgi'
require 'date'
require_relative 'markdown'

VAULT   = File.expand_path('..', __dir__) # this script lives in <vault>/.tools/
TRACKER = File.join(VAULT, 'S0', 'Internal Builds', 'Pipeline Tracker')
BASE    = File.join(TRACKER, 'Priority Ranking.base')
INTAKE  = File.join(TRACKER, 'Intake')
SITE    = File.join(VAULT, '.tracker-site')
OUT     = File.join(SITE, 'index.html')

FIELDS = %w[roi strategic impact urgency culture complexity].freeze
LABELS = {
  'roi' => 'Revenue ROI', 'strategic' => 'Strategic', 'impact' => 'Client Impact',
  'urgency' => 'Urgency', 'culture' => 'Culture', 'complexity' => 'Complexity'
}.freeze

# Reference pages published alongside the intake notes. This is an ALLOWLIST,
# never a link crawl. Every entry cites [[Scoring Rubric]], and the rubric plus
# the operating doc are what make a score legible to someone landing on a note
# from the ranking. Deliberately absent: Publishing.md (visibility:
# internal-only), the READMEs, and
# everything outside this folder — a crawl would drag in the charter and
# Benchmark Discipline, which the charter forbids publishing.
# Publication is opt-in from the NOTE, not from this file. Tag a doc in the
# tracker folder with this and it publishes on the next push, inheriting the
# whole template — no code change. Untag it and it stops. That is the same gate
# load_rows already uses for intake notes (tags include 'executive-intake'), so
# there is one mechanism here, not two.
#
# Deliberately opt-in rather than "publish everything except X": a new file in
# this folder must never publish because someone forgot to exclude it. The glob
# is also folder-scoped, so it cannot reach the charter or Benchmark Discipline
# no matter what is tagged — CLAUDE.md forbids this ever becoming a link crawl.
#
# Named 'publish-to-site' and not 'publish' because Publishing.md carries the tag
# 'publishing'; exact matching keeps them apart, but a human reading frontmatter
# should not have to squint.
DOC_TAG = 'publish-to-site'

# Statuses meaning "delivered". Kept out of the priority table: a finished
# project outranking live work under a heading that says "Priority ranking"
# reads as "do this next" to the one audience that matters.
DONE = %w[Shipped Done].freeze

AWAITING = 'Awaiting scoring'

# --- weights: parsed from the .base formula, never hardcoded here -------------
def load_weights
  formula = YAML.load_file(BASE).dig('formulas', 'overall')
  abort "FATAL: no 'overall' formula in #{BASE}" unless formula
  FIELDS.to_h do |f|
    m = formula.match(/([+\-(])\s*(\d*\.?\d+)\s*\*\s*note\.#{f}\b/)
    abort "FATAL: no coefficient for '#{f}' in the .base formula" unless m
    [f, m[2].to_f * (m[1] == '-' ? -1 : 1)]
  end
end

# --- scoring -----------------------------------------------------------------
# Single code path for the score, so --check can exercise it with a fixture
# instead of asserting against a live note. Asserting on vault data made any
# legitimate re-score fail CI and block the deploy.
def compute_overall(scores, weights)
  return nil unless scores.values.all? { |v| v.is_a?(Numeric) }

  scores.sum { |f, v| weights[f] * v }.round(2)
end

def slug(name)
  name.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
end

# Obsidian accepts three tag forms: a block sequence, `tags: [a, b]`, and the
# bare scalar `tags: a`. Only the first two yield an Array, and String#to_a was
# removed in Ruby 1.9 — so `fm['tags'].to_a` raised NoMethodError on the scalar
# form and killed the render for EVERY note, not just the offending one.
def tag_list(value)
  case value
  when Array  then value.map(&:to_s)
  when String then value.split(/[,\s]+/).reject(&:empty?)
  when nil    then []
  else [value.to_s]
  end
end

# Parses a LEADING YAML frontmatter block, or returns {} when the file has none.
#
# The leading-fence guard is load-bearing, not defensive. load_docs globs a whole
# folder, and README.md has no frontmatter but does use --- as a horizontal rule.
# Splitting on /^---$/ regardless then handed body prose to the YAML parser,
# which raised Psych::SyntaxError and aborted the entire render — one untagged
# file taking down every page. load_rows shares the same shape and only escaped
# it because Intake/ holds nothing but real intake notes.
def frontmatter(raw)
  return {} unless raw.start_with?("---\n")

  YAML.safe_load(raw.split(/^---[ \t]*$/)[1].to_s,
                 permitted_classes: [Date], aliases: true) || {}
end

# Scores are a trust boundary: YAML hands back whatever was typed, and a score
# is the one note-derived value that used to reach HTML without escaping. A
# non-number is dropped to nil (so it cannot total into a ranking) and reported,
# so a quoted "2" fails the build loudly instead of silently unscoring the row.
def validated_scores(fm)
  issues = []
  scores = FIELDS.to_h do |f|
    v = fm[f]
    unless v.nil? || v.is_a?(Integer) || v.is_a?(Float)
      issues << "#{f} is #{v.class} #{v.inspect} — scores must be unquoted numbers"
      v = nil
    end
    [f, v]
  end
  [scores, issues]
end

# --- rows --------------------------------------------------------------------
def load_rows(weights)
  # .map{}.compact rather than filter_map — Ruby 2.6 compatibility
  Dir.glob(File.join(INTAKE, '*.md')).sort.map do |path|
    name = File.basename(path, '.md')
    # Templates live in <vault>/_Templates and are never read here. This guard
    # only catches a template copied into Intake/ but not yet renamed.
    next if name.start_with?('Executive Intake Entry')

    # Normalise line endings on read. markdown.rb's frontmatter fence and this
    # split must agree about what a fence is; when they disagreed, a CRLF note
    # ranked normally while publishing its whole YAML block as page text.
    raw = File.read(path).gsub(/\r\n?/, "\n")
    fm = frontmatter(raw)
    next unless tag_list(fm['tags']).include?('executive-intake')

    scores, issues = validated_scores(fm)
    { name: name, overall: compute_overall(scores, weights), scores: scores,
      slot: fm['slot'].to_s, status: fm['status'].to_s,
      logged: fm['logged'].to_s, shipped: fm['shipped'].to_s,
      by: fm['logged_by'].to_s, verbatim: fm['verbatim'].to_s,
      interpreted: fm['interpreted'].to_s, issues: issues,
      href: "#{slug(name)}.html", body: raw }
  end.compact
end

def load_docs
  # .map{}.compact rather than filter_map — Ruby 2.6 compatibility
  Dir.glob(File.join(TRACKER, '*.md')).sort.map do |path|
    name = File.basename(path, '.md')
    # Normalise line endings on read, as load_rows does. A CRLF note used to
    # publish its whole YAML block as page text because this parser's fence and
    # markdown.rb's disagreed about what a fence is.
    raw = File.read(path).gsub(/\r\n?/, "\n")
    fm = frontmatter(raw)
    # tag_list, not a second parser: it already handles the block sequence, the
    # inline array and the bare scalar. README.md has no frontmatter at all, so it
    # falls out here without needing a special case.
    next unless tag_list(fm['tags']).include?(DOC_TAG)

    { name: name, href: "#{slug(name)}.html", body: raw }
  end.compact
end

# Wikilink target -> page. Anything absent renders as plain text, which enforces
# the allowlist at the link level rather than hoping nobody clicks.
def build_links(rows, docs)
  links = {}
  (rows + docs).each { |r| links[r[:name]] = r[:href] }
  # The base IS the ranking tables, so its wikilink resolves to the index. This
  # mirrors Pipeline Tracker.md embedding ![[Priority Ranking.base]] in Obsidian.
  links['Priority Ranking.base'] = 'index.html'
  links['Priority Ranking'] = 'index.html'
  links
end

# --- html --------------------------------------------------------------------
def h(str) # macOS ships Ruby 2.6; no endless method defs
  CGI.escapeHTML(str.to_s)
end

# Every published note opens with a `# Title` that repeats the title this
# renderer already emits, so the doc pages rendered two identical 42px headlines
# with the banner wedged between them. Strips only a LEADING h1; mid-body
# headings are untouched.
def strip_leading_h1(body)
  s = body.to_s
  # Published notes open with a YAML frontmatter block, so the h1 is not at \A.
  # The frontmatter is preserved verbatim and handed on — markdown.rb strips it
  # itself, and removing it here would change what that parser sees.
  fm = s.match(/\A---[ \t]*\n.*?\n---[ \t]*\n/m)
  return s.sub(/\A(?:\s*\n)*\#[ \t]+.*\n/, '') unless fm

  fm[0] + s[fm[0].length..-1].to_s.sub(/\A(?:\s*\n)*\#[ \t]+.*\n/, '')
end

# Mermaid needs a JavaScript renderer to draw a graph, and this site makes zero
# external requests — vendoring one would be megabytes for a single diagram.
# But every flowchart in the vault is a LINEAR chain, and a linear chain is just
# a numbered sequence, which is readable and needs no library at all.
#
# So: parse that one shape and emit real markup for it. Anything else returns nil
# and keeps its verbatim block, because a half-drawn graph is worse than source.
def mermaid_to_flow(src)
  body = src.to_s
  return nil unless body =~ /\A\s*flowchart\s+(?:LR|RL|TD|TB)\b/

  nodes = {}
  body.scan(/([A-Za-z0-9_]+)\[([^\]]+)\]/) { |id, label| nodes[id] = label }
  # Edges are parsed from a LABEL-FREE skeleton. Scanning the raw text matched the
  # last word inside a label instead of the node id — on
  # "A[Executive Intake<br/>verbal ask] --> B[...]" it captured "ask --> B",
  # inventing a node and orphaning A, so the chain looked non-linear and silently
  # fell back to the source block.
  skeleton = body.gsub(/([A-Za-z0-9_]+)\[[^\]]*\]/) { Regexp.last_match(1) }
  edges = skeleton.scan(/([A-Za-z0-9_]+)\s*--+>\s*([A-Za-z0-9_]+)/)
  return nil if nodes.empty? || edges.empty?

  froms = edges.map { |e| e[0] }
  tos   = edges.map { |e| e[1] }
  # Linear means each node has at most one edge in and one out. A fan-out or a
  # join is a real graph and must not be flattened into a false sequence.
  return nil unless froms.uniq.size == froms.size && tos.uniq.size == tos.size

  cursor = (froms - tos).first
  return nil unless cursor

  nxt = Hash[edges]
  order = [cursor]
  order << (cursor = nxt[cursor]) while nxt[cursor]
  return nil unless order.size == nodes.size

  steps = order.each_with_index.map do |id, i|
    parts = nodes[id].to_s.split(%r{<br\s*/?>}).map { |s| h(s.strip) }
    title = parts.shift.to_s
    sub   = parts.empty? ? '' : %(<span class="flow-s">#{parts.join(' ')}</span>)
    %(<li><span class="flow-n">#{format('%02d', i + 1)}</span><span class="flow-t">#{title}</span>#{sub}</li>)
  end
  %(<ol class="flow">#{steps.join}</ol>)
end

# Post-processes rendered HTML. Runs after Markdown.render because the mermaid
# body arrives HTML-escaped inside the preformatted block.
def enrich(html)
  html.gsub(%r{<pre class="lang-mermaid"><code>(.*?)</code></pre>}m) do
    # Capture BOTH groups to locals first. mermaid_to_flow runs its own regexes,
    # which reset Regexp.last_match, so reading last_match(0) after calling it
    # would return that function's last internal match instead of this block.
    whole = Regexp.last_match(0)
    inner = Regexp.last_match(1)
    mermaid_to_flow(CGI.unescapeHTML(inner)) || whole
  end
end

CSS = <<~CSS
  /* ---------------------------------------------------------------------------
     futurify.ai v0 — the tracker's entire stylesheet, one coherent sheet.
     Every value lives in exactly ONE place. An earlier version kept the motif
     band height in two (block-size and mask-size) and they drifted apart, so
     sizes that must agree are tokens now, not repeated literals.

     Two tones carry the identity and there is no accent colour. The system
     spends colour on exactly two things — STATE and DATA — and this page has
     both: slot/status are state, the six scoring dimensions are data.
     --------------------------------------------------------------------------- */

  /* Faces. Self-hosted, same-origin, never a CDN: the brand package forbids
     external font requests. Latin subsets only, 65 KB for all four; missing
     glyphs fall through the stack per-glyph, hence no unicode-range. */
  @font-face{font-family:"Space Grotesk";font-style:normal;font-weight:400 700;font-display:swap;src:url("fonts/space-grotesk-latin.woff2") format("woff2")}
  @font-face{font-family:"Manrope";font-style:normal;font-weight:400 700;font-display:swap;src:url("fonts/manrope-latin.woff2") format("woff2")}
  @font-face{font-family:"IBM Plex Mono";font-style:normal;font-weight:400;font-display:swap;src:url("fonts/plex-mono-400-latin.woff2") format("woff2")}
  @font-face{font-family:"IBM Plex Mono";font-style:normal;font-weight:500;font-display:swap;src:url("fonts/plex-mono-500-latin.woff2") format("woff2")}
  /* Metric-matched fallbacks, so first paint does not shift. Measured upstream:
     Manrope 1.95% off Helvetica, Plex Mono 0.02% off Courier. */
  @font-face{font-family:"Space Grotesk Fallback";src:local("Helvetica Neue"),local("Helvetica"),local("Arial");size-adjust:108.21%;ascent-override:98%;descent-override:29%;line-gap-override:0%}
  @font-face{font-family:"Manrope Fallback";src:local("Helvetica Neue"),local("Helvetica"),local("Arial");size-adjust:101.95%;ascent-override:107%;descent-override:30%;line-gap-override:0%}
  @font-face{font-family:"IBM Plex Mono Fallback";src:local("Courier New"),local("Courier");size-adjust:99.98%;ascent-override:102%;descent-override:27%;line-gap-override:0%}

  /* Theme-independent tokens. Sizes are the design system's measured anchors,
     not a ratio scale: 42 / 30 / 19 / 18.5 / 17 / 14.5 / 12.5 / 11.5 / 11. */
  :root{
    --display:"Space Grotesk","Space Grotesk Fallback",ui-sans-serif,system-ui,sans-serif;
    --body:"Manrope","Manrope Fallback",ui-sans-serif,system-ui,sans-serif;
    --mono:"IBM Plex Mono","IBM Plex Mono Fallback",ui-monospace,monospace;
    --band:174px;      /* motif band: 2 cells at 87px. ONE definition. */
    --container:1320px;/* wider than the system's 1080 so 11 columns fit unscrolled */
    --gutter:1.5rem;
    --prose:70ch;
  }

  /* Colour. Light is primary and also the bare-:root default, so a page renders
     correctly before any script runs. Dark is the design system's SEPARATELY
     SELECTED set, never an inversion of light. Neither tone is pure: paper is a
     warm off-white and ink a warm near-black, so the page is easy on the eye
     without the shift being obvious.

     All three blocks declare the IDENTICAL key list. A key present in only one
     silently inherits the wrong value with no error. The data-theme stamp beats
     the OS preference in both directions, which is what makes the toggle work. */
  :root,:root[data-theme="light"]{
    --bg:#faf9f6;--fg:#111110;--dim:#6f6d66;--line:#dcd9d0;--codebg:#f2f0ea;
    --warn:#89601f;--ok:#3c633d;--info:#43607e;--bad:#96372b;
    --c1:#bc4b37;--c2:#3464a0;--c3:#d19936;--c4:#833575;--c5:#509c63;
  }
  @media (prefers-color-scheme:dark){
    :root:not([data-theme="light"]){
      --bg:#111110;--fg:#faf9f6;--dim:#9b9992;--line:#2e2d2a;--codebg:#1b1b19;
      --warn:#e1b66c;--ok:#81b482;--info:#83a8cf;--bad:#dd7767;
      --c1:#d4614c;--c2:#447dc4;--c3:#bd891c;--c4:#964fa1;--c5:#4e9f63;
    }
  }
  :root[data-theme="dark"]{
    --bg:#111110;--fg:#faf9f6;--dim:#9b9992;--line:#2e2d2a;--codebg:#1b1b19;
    --warn:#e1b66c;--ok:#81b482;--info:#83a8cf;--bad:#dd7767;
    --c1:#d4614c;--c2:#447dc4;--c3:#bd891c;--c4:#964fa1;--c5:#4e9f63;
  }
  :root{color-scheme:light dark}

  /* Base ------------------------------------------------------------------- */
  *{box-sizing:border-box}
  body{margin:0;padding:0;background:var(--bg);color:var(--fg);font-family:var(--body);
       font-size:1.0625rem;line-height:1.62;overflow-x:hidden;-webkit-font-smoothing:antialiased}
  main{max-width:var(--container);margin:0 auto;padding:0 var(--gutter) 5.25rem}
  ::selection{background:var(--fg);color:var(--bg)}
  :focus-visible{outline:2px solid var(--fg);outline-offset:3px}

  /* Type. The identity's loudest move is the tracking split: display pulls in to
     -0.02em, the mono label voice pushes out to +0.12em, nothing sits at zero. */
  h1,h2,h3{font-family:var(--display);letter-spacing:-.02em;font-weight:600;text-wrap:balance}
  h1{font-size:clamp(30px,6vw,42px);line-height:1.12;margin:0 0 .75rem;max-width:26ch}
  h2{font-size:clamp(22px,4.2vw,30px);line-height:1.14;margin:3.5rem 0 1rem;max-width:26ch}
  h3{font-size:19px;line-height:1.3;margin:2.25rem 0 .5rem}
  h4{font-family:var(--mono);font-size:11.5px;font-weight:500;text-transform:uppercase;
     letter-spacing:.12em;color:var(--dim);margin:2rem 0 .5rem}
  p{max-width:var(--prose);text-wrap:pretty}
  ul,ol{padding-left:1.4rem;max-width:var(--prose)}
  li{margin:.3rem 0}
  .sub{color:var(--dim);margin:0 0 2rem;font-size:19px;max-width:66ch}
  a{color:var(--fg);text-decoration:underline;text-underline-offset:3px}
  a:hover{opacity:.62}
  del{color:var(--dim)}
  hr{border:0;border-top:1px solid var(--line);margin:1.75rem 0}

  /* The mono label voice does the work an icon usually does: it names the thing
     rather than symbolising it. This identity ships no icon set, by design. */
  .crumb{display:inline-flex;align-items:center;gap:10px;min-height:24px;margin:0 0 2rem;
         font-family:var(--mono);font-size:12.5px;font-weight:500;text-transform:uppercase;
         letter-spacing:.14em;text-decoration:none}
  .crumb::before{content:"";inline-size:9px;block-size:9px;background:currentColor;flex:none;
                 clip-path:polygon(30% 0,70% 0,100% 30%,100% 70%,70% 100%,30% 100%,0 70%,0 30%)}
  .crumb:hover{text-decoration:underline}

  /* Masthead + theme toggle ------------------------------------------------- */
  .masthead{display:flex;align-items:center;gap:.65rem;max-width:var(--container);
            margin:0 auto;padding:2rem var(--gutter) 0}
  .mark{display:inline-block;width:15px;height:15px;background:currentColor;
        clip-path:polygon(0 0,100% 0,0 100%);flex:none}
  .wm{font-family:var(--mono);font-size:11.5px;font-weight:500;text-transform:uppercase;
      letter-spacing:.24em;color:var(--dim)}
  .tt{margin-left:auto;background:none;color:var(--dim);border:1px solid var(--line);
      border-radius:2px;font-family:var(--mono);font-size:11px;font-weight:500;
      text-transform:uppercase;letter-spacing:.12em;padding:7px 12px;min-height:32px;cursor:pointer}
  .tt:hover{color:var(--fg);border-color:var(--fg)}
  /* The button says which mode it switches TO. The mark is a quilt cell split
     paper/ink, so it reads as a light-dark control without an icon set — this
     identity ships none. */
  .tt-m{display:inline-block;width:9px;height:9px;margin-right:7px;
        background:linear-gradient(135deg,currentColor 0 50%,transparent 50% 100%);
        border:1px solid currentColor;border-radius:1px;vertical-align:-1px}

  /* The confidentiality notice runs full bleed on the ink plane — the identity's
     loudest surface. The inner padding keeps its text on main's column. */
  .banner{background:var(--fg);color:var(--bg);border-radius:0;font-weight:600;margin-bottom:2rem;
          margin-inline:calc(50% - 50vw);width:100vw;
          padding:.85rem max(var(--gutter),calc(50vw - (var(--container) / 2) + var(--gutter)))}
  .banner::selection{background:var(--bg);color:var(--fg)}

  /* Tables. No horizontal scroll: cells wrap instead, so the whole row is
     readable at once. .scroll stays as a safety net because body has
     overflow-x:hidden — anything that did overflow would be clipped, not
     scrollable — but at this container width it should never engage. */
  .scroll{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:.75rem 0}
  table{border-collapse:collapse;width:100%;font-size:14px;font-variant-numeric:tabular-nums}
  th,td{text-align:left;padding:.75rem .6rem .75rem 0;border-bottom:1px solid var(--line);
        vertical-align:top;overflow-wrap:break-word}
  thead th{font-family:var(--mono);font-weight:500;font-size:11.5px;text-transform:uppercase;
           letter-spacing:.1em;color:var(--dim);padding-bottom:.625rem;line-height:1.3}
  tbody tr:hover{background:var(--codebg)}
  .ranking td:first-child,.ranking th:first-child{min-width:14rem}
  .score{font-weight:700}
  /* DATA colour: the five validated chart slots in their fixed order
     (oxide, slate, brass, plum, moss) mark the five value dimensions. The order
     is a colour-vision safety mechanism, not a preference, so it is not
     reordered. Slot 3 sits below 3:1 on paper, which is why the spec requires
     direct labels or a table view for anything using it — this is a table with
     labelled headers, so that condition is met, and the hue is carried by a
     3px rule rather than by text. Complexity takes the state colour instead of a
     sixth slot: it is the one dimension that SUBTRACTS, so it is not a peer. */
  .dim{border-top:3px solid var(--line)}
  .d1{border-top-color:var(--c1)}
  .d2{border-top-color:var(--c2)}
  .d3{border-top-color:var(--c3)}
  .d4{border-top-color:var(--c4)}
  .d5{border-top-color:var(--c5)}
  .d6{border-top-color:var(--bad)}

  /* State: a word plus a mark, never colour alone. The mark is one quilt cell
     clipped from currentColor, so meaning survives without the hue. */
  .status{display:inline-flex;align-items:center;gap:7px;font-family:var(--mono);
          font-size:11.5px;letter-spacing:.08em;text-transform:uppercase}
  .status::before{content:"";inline-size:8px;block-size:8px;flex:none;
                  background:currentColor;clip-path:polygon(0 0,100% 0,0 100%)}
  .status--ok{color:var(--ok)}
  .status--info{color:var(--info)}
  .status--bad{color:var(--bad)}
  .status--idle{color:var(--dim)}

  /* Chips carry the mono voice at the 1.5px emphasis stroke; at the decorative
     1px hairline (1.34:1) they read as stray table cells. */
  .cards{display:flex;flex-wrap:wrap;gap:.5rem;margin:.75rem 0 1.25rem}
  .card{display:inline-flex;align-items:center;gap:8px;min-block-size:32px;padding:6px 14px;
        font-family:var(--mono);font-size:12.5px;letter-spacing:.04em;
        border:1.5px solid currentColor;border-radius:2px;white-space:nowrap}
  .card b{font-variant-numeric:tabular-nums}
  .empty{color:var(--dim);font-family:var(--mono);font-size:14px}

  /* Quotes and code. The recessed plane measures 1.08:1 against paper, so it is
     invisible alone — the system always pairs it with the 1px hairline, which is
     this identity's only separation device. */
  blockquote{margin:1rem 0;padding:.1rem 1rem;border-left:3px solid var(--line);max-width:78ch}
  blockquote.callout{border-left:3px solid currentColor;padding:.6rem 1rem}
  blockquote.callout-warning{border-left-color:var(--warn)}
  .callout-title{font-weight:700;margin:.2rem 0;color:var(--dim)}
  code{background:var(--codebg);border:1px solid var(--line);font-family:var(--mono);
       padding:.1em .35em;border-radius:2px;font-size:.84em}
  /* Formulae live in these blocks, so they are set large enough to read as
     notation rather than as a code dump, and they WRAP instead of scrolling —
     a formula that runs off the right edge is not readable at all. */
  pre{background:var(--codebg);border:1px solid var(--line);padding:1.125rem 1.25rem;
      border-radius:2px;margin:1.375rem 0;overflow-x:auto}
  pre code{background:none;border:0;padding:0;font-size:15px;line-height:1.8;
           white-space:pre-wrap;overflow-wrap:break-word}

  /* A linear mermaid flowchart, rendered as the numbered sequence it actually is.
     Mermaid's own renderer is a JS library this site will not load; a chain needs
     no library. Non-linear diagrams keep their source block instead. */
  .flow{list-style:none;display:grid;gap:1px;padding:0;margin:1.25rem 0 2rem;
        max-width:none;background:var(--line);border:1px solid var(--line);border-radius:2px;
        grid-template-columns:repeat(auto-fit,minmax(150px,1fr))}
  .flow li{background:var(--bg);padding:.9rem 1rem;display:flex;flex-direction:column;gap:3px}
  .flow-n{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:.14em;
          color:var(--dim)}
  .flow-t{font-family:var(--display);font-size:15px;font-weight:600;letter-spacing:-.01em;
          line-height:1.2}
  .flow-s{font-size:13px;color:var(--dim);line-height:1.4}

  footer{margin-top:2.5rem;padding-top:1rem;border-top:1px solid var(--line);
         color:var(--dim);font-size:14px;max-width:78ch}

  /* The quilt is this identity's only decoration — half-square triangles,
     direction alternating on a checkerboard, about 58% inked, deterministic
     (Park-Miller, seed 97). Inlined as a MASK, never a background-image: the
     source SVG carries a literal ink fill, so as a background it would paint ink
     regardless of theme and vanish on an ink surface. The SVG gives the shape,
     the theme gives the colour through currentColor. Height comes from --band in
     both places so the box and the mask cannot drift apart. */
  .quilt-band{block-size:var(--band);background-color:currentColor;color:var(--fg);
              mask-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1740 174'%3E%3Cpath d='M87 0L87 87L0 87ZM435 0L522 0L522 87ZM696 0L783 0L696 87ZM783 0L870 0L870 87ZM957 0L957 87L870 87ZM957 0L1044 0L1044 87ZM1044 0L1131 0L1044 87ZM1131 0L1131 87L1044 87ZM1131 0L1218 0L1218 87ZM1305 0L1392 0L1392 87ZM1479 0L1479 87L1392 87ZM1479 0L1566 0L1566 87ZM1479 0L1566 87L1479 87ZM1653 0L1653 87L1566 87ZM1653 0L1740 0L1740 87ZM1653 0L1740 87L1653 87ZM0 87L87 87L87 174ZM87 87L174 87L87 174ZM174 87L174 174L87 174ZM174 87L261 87L261 174ZM261 87L348 87L261 174ZM348 87L348 174L261 174ZM348 87L435 174L348 174ZM522 87L609 87L609 174ZM609 87L696 87L609 174ZM696 87L696 174L609 174ZM696 87L783 174L696 174ZM870 87L957 87L957 174ZM957 87L1044 87L957 174ZM1044 87L1131 174L1044 174ZM1131 87L1218 87L1131 174ZM1218 87L1218 174L1131 174ZM1218 87L1305 174L1218 174ZM1305 87L1392 87L1305 174ZM1392 87L1392 174L1305 174ZM1740 87L1740 174L1653 174Z'/%3E%3C/svg%3E");
              mask-repeat:repeat-x;mask-size:auto var(--band);mask-position:left top;margin:4rem 0 0}
  @media (max-width:640px){:root{--band:87px}}

  /* Forced colours: the UA discards the brand steps, so borders are re-asserted
     because de-filled headers and callouts leave borders as the only structure,
     and the focus ring must take Highlight or it renders in the same CanvasText
     as every hairline and stops reading as a ring. The quilt and the mark are
     decorative, so they are allowed to go rather than being faked with a border
     that would read as structure. */
  @media (forced-colors:active){
    *{border-color:CanvasText}
    :focus-visible{outline-color:Highlight}
    .banner{border:1px solid CanvasText}
    .quilt-band{display:none}
  }
CSS

BANNER = 'Internal &amp; commercially confidential. This site is public — treat anything written in an intake note as world-readable.'

def page(title, body, footer)
  <<~HTML
    <!doctype html>
    <html lang="en"><head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title>#{h(title)}</title>
    <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Crect width='16' height='16' fill='%23faf9f6'/%3E%3Cpath d='M0 0h16L0 16z' fill='%23111110'/%3E%3C/svg%3E">
    <script>(function(){try{var s=localStorage.getItem("s0-theme");if(s){document.documentElement.setAttribute("data-theme",s)}}catch(e){}})();</script>
    <style>#{CSS}</style></head><body>
    <div class="masthead"><span class="mark" aria-hidden="true"></span><span class="wm">S0 &middot; Internal Builds</span>
    <button class="tt" id="tt" type="button"><span class="tt-m" aria-hidden="true"></span><span id="ttl">Dark</span> mode</button></div>
    <main>
    #{body}
    <footer>#{footer}</footer>
    </main>
    <div class="quilt-band" aria-hidden="true"></div>
    <script>(function(){var r=document.documentElement,b=document.getElementById("tt"),l=document.getElementById("ttl");if(!b){return}
    function now(){return r.getAttribute("data-theme")||(window.matchMedia("(prefers-color-scheme:dark)").matches?"dark":"light")}
    function label(){var t=now()==="dark"?"Light":"Dark";if(l){l.textContent=t}
    b.setAttribute("aria-label","Switch to "+t.toLowerCase()+" mode")}
    label();
    b.addEventListener("click",function(){var nxt=now()==="dark"?"light":"dark";
    r.setAttribute("data-theme",nxt);try{localStorage.setItem("s0-theme",nxt)}catch(e){}label()});})();</script>
    </body></html>
  HTML
end

# Slot and status are STATE, which is one of the two things this design system
# spends colour on. Tone names are looked up from a frozen map with an idle
# default, never interpolated from the value, so the self-check's hostile-input
# row cannot inject a class. h() still escapes the visible text.
#
# Next maps to info rather than idle: it is a ranked, accepted position awaiting
# capacity, not an absence of one. Idle is reserved for a value we do not know.
STATUS_TONE = {
  'now' => 'ok', 'shipped' => 'ok', 'done' => 'ok',
  'next' => 'info', 'scored' => 'info',
  'blocked' => 'bad'
}.freeze

def status_pill(value)
  text = value.to_s.strip
  return '' if text.empty?

  %(<span class="status status--#{STATUS_TONE[text.downcase] || 'idle'}">#{h(text)}</span>)
end

def ranked_table(rows, empty = 'No scored items yet.')
  return %(<p class="empty">#{h(empty)}</p>) if rows.empty?

  # The six dimension columns carry a chart-slot rule so the reader can tell
  # which column is which at a glance. Classes come from the fixed FIELDS index,
  # never from note content, so nothing user-supplied reaches a class name.
  head = [['Ask', nil], ['Overall', nil], ['Slot', nil], ['Status', nil],
          *FIELDS.each_with_index.map { |f, i| [LABELS[f], "dim d#{i + 1}"] },
          ['Logged', nil]]
  body = rows.map do |r|
    ask = %(<a href="#{r[:href]}">#{h(r[:name])}</a>)
    # Both the nil guard and h() on the scores are load-bearing. Without the
    # guard, an unscored row in this bucket aborts the whole render; without
    # h(), a non-numeric score reaches the highest-traffic page as raw markup —
    # and fixing only the guard is what would have exposed the second.
    overall = r[:overall] ? format('%.2f', r[:overall]) : '&mdash;'
    cells = [ask, overall, status_pill(r[:slot]), status_pill(r[:status]),
             *FIELDS.map { |f| h(r[:scores][f]) }, h(r[:logged])]
    tds = cells.each_with_index.map { |c, i| i == 1 ? %(<td class="score">#{c}</td>) : "<td>#{c}</td>" }
    "<tr>#{tds.join}</tr>"
  end
  <<~HTML
    <div class="scroll"><table class="ranking">
      <thead><tr>#{head.map { |c, cls| cls ? %(<th class="#{cls}">#{h(c)}</th>) : "<th>#{h(c)}</th>" }.join}</tr></thead>
      <tbody>#{body.join}</tbody>
    </table></div>
  HTML
end

def awaiting_table(rows)
  return '<p class="empty">Nothing awaiting scoring.</p>' if rows.empty?

  body = rows.map do |r|
    %(<tr><td><a href="#{r[:href]}">#{h(r[:name])}</a></td><td>#{h(r[:verbatim])}</td>) +
      "<td>#{h(r[:logged])}</td><td>#{h(r[:by])}</td></tr>"
  end
  <<~HTML
    <div class="scroll"><table>
      <thead><tr><th>Ask</th><th>Verbatim</th><th>Logged</th><th>By</th></tr></thead>
      <tbody>#{body.join}</tbody>
    </table></div>
  HTML
end

def index_page(rows, docs, weights, stamp, pages)
  # Built from the docs actually LOADED, never from the tag filter. Building
  # it from the constant emitted a link to a page that was never written when a
  # reference doc had been renamed or removed — a 404 a reader finds by clicking.
  reference =
    if docs.empty?
      ''
    else
      items = docs.map { |d| %(<li><a href="#{d[:href]}">#{h(d[:name])}</a></li>) }.join
      "<h2>Reference</h2>\n<ul>#{items}</ul>"
    end
  awaiting = rows.select { |r| r[:status] == AWAITING }
  shipped  = rows.select { |r| DONE.include?(r[:status]) }.sort_by { |r| -(r[:overall] || -99) }
  ranked   = rows.reject { |r| r[:status] == AWAITING || DONE.include?(r[:status]) }
                 .sort_by { |r| -(r[:overall] || -99) }
  formula  = FIELDS.map { |f| format('%+g·%s', weights[f], LABELS[f]) }.join(' ')

  body = <<~HTML
    <h1>Pipeline Tracker — Priority Ranking</h1>
    <p class="sub">Executive Intake asks, scored and ranked. Read-only — every ask name links to its full entry.</p>
    <div class="banner">#{BANNER}</div>
    <h2>Priority ranking</h2>
    #{ranked_table(ranked)}
    <h2>Awaiting scoring</h2>
    #{awaiting_table(awaiting)}
    <h2>Shipped</h2>
    <p class="sub">Delivered. Scores kept as a record of what shipped and what it cost &mdash; not a queue.</p>
    #{ranked_table(shipped, 'Nothing shipped yet.')}
    #{reference}
  HTML

  footer = "Generated #{h(stamp)} · #{ranked.size} ranked, #{shipped.size} shipped, " \
           "#{awaiting.size} awaiting · #{pages} pages.<br>" \
           "Overall = #{h(formula)} &nbsp;(each 1&ndash;5) &mdash; weights read live from " \
           '<code>Priority Ranking.base</code>, so this page and the vault cannot disagree.'
  page('Pipeline Tracker — Priority Ranking', body, footer)
end

def score_cards(row)
  cards = []
  cards << %(<span class="card">Overall <b>#{format('%.2f', row[:overall])}</b></span>) if row[:overall]
  cards << %(<span class="card">Slot #{h(row[:slot])}</span>) unless row[:slot].empty?
  cards << %(<span class="card">#{h(row[:status])}</span>) unless row[:status].empty?
  FIELDS.each do |f|
    v = row[:scores][f]
    cards << %(<span class="card">#{h(LABELS[f])} <b>#{h(v)}</b></span>) unless v.nil?
  end
  cards << %(<span class="card">Logged #{h(row[:logged])}</span>) unless row[:logged].empty?
  cards << %(<span class="card">Shipped #{h(row[:shipped])}</span>) unless row[:shipped].empty?
  cards.join
end

def note_page(row, links, stamp)
  body = <<~HTML
    <a class="crumb" href="index.html">&larr; Priority ranking</a>
    <h1>#{h(row[:name])}</h1>
    <div class="banner">#{BANNER}</div>
    <div class="cards">#{score_cards(row)}</div>
    #{enrich(Markdown.render(strip_leading_h1(row[:body]), links))}
  HTML
  page("#{row[:name]} — Pipeline Tracker", body,
       "Generated #{h(stamp)} · Executive Intake entry.")
end

def doc_page(doc, links, stamp)
  body = <<~HTML
    <a class="crumb" href="index.html">&larr; Priority ranking</a>
    <h1>#{h(doc[:name])}</h1>
    <div class="banner">#{BANNER}</div>
    #{enrich(Markdown.render(strip_leading_h1(doc[:body]), links))}
  HTML
  page("#{doc[:name]} — Pipeline Tracker", body, "Generated #{h(stamp)} · Reference.")
end

# Renders every page into memory, keyed by filename. Two reasons this is not
# written straight to disk. First, --check can then exercise the REAL render
# path: the previous check never called ranked_table or index_page, so it
# printed OK on input that aborted the render seconds later. Second, clean_site
# can run after a successful build instead of before — a mid-render abort used
# to leave the site directory emptied.
def build_pages(rows, docs, weights, links, stamp)
  total = 1 + rows.size + docs.size
  pages = { 'index.html' => index_page(rows, docs, weights, stamp, total) }
  rows.each { |r| pages[r[:href]] = note_page(r, links, stamp) }
  docs.each { |d| pages[d[:href]] = doc_page(d, links, stamp) }
  pages
end

# Every internal href must land on a page we actually write. The previous check
# compared the links hash against a list derived from that same hash, so it was a
# tautology that could not fail. This reads the rendered HTML instead.
def dangling_links(pages)
  bad = []
  pages.each do |name, html|
    html.scan(/href="([^"]+)"/).flatten.uniq.each do |target|
      # Skip fragments and anything carrying a URI scheme. This was a hardcoded
      # list of http/#/mailto, which meant the first data: URI added to the page
      # (an inlined favicon) was read as a dangling page link and aborted the
      # whole render. A scheme test covers data:, tel:, blob: and whatever comes
      # next, so only genuinely relative targets are checked against the pages.
      next if target.start_with?('#') || target.match?(/\A[a-z][a-z0-9+.-]*:/i)

      bad << "#{name} -> #{target}" unless pages.key?(target)
    end
  end
  bad
end

# Full rebuild. A page for a retracted ask must not survive a local run and get
# re-uploaded on the next deploy — that is the disclosure failure Publishing.md
# names. CI checks out fresh, but a working copy would otherwise accumulate.
def clean_site
  Dir.mkdir(SITE) unless Dir.exist?(SITE)
  Dir.glob(File.join(SITE, '*.html')).each { |f| File.delete(f) }
  copy_fonts
end

# The three brand faces are self-hosted because the design system forbids
# external font requests. Until now only the local() metric-matched shims
# shipped, so any viewer without the faces installed — which is essentially
# everyone — read the whole site in Helvetica and Courier.
#
# Source is .tools/fonts, which is TRACKED. Fonts placed under .tracker-site
# instead would pass every local check (the files exist on the author's disk)
# and 404 in production, because .tracker-site is gitignored and CI checks out
# fresh. That is the same stale-sidecar failure clean_site exists to prevent,
# so the copy is cleared and re-made on every run rather than accumulating.
def copy_fonts
  dst = File.join(SITE, 'fonts')
  Dir.mkdir(dst) unless Dir.exist?(dst)
  Dir.glob(File.join(dst, '*.woff2')).each { |f| File.delete(f) }
  Dir.glob(File.join(__dir__, 'fonts', '*.woff2')).each do |src|
    File.binwrite(File.join(dst, File.basename(src)), File.binread(src))
  end
end

# --- main --------------------------------------------------------------------
weights = load_weights
rows    = load_rows(weights)
docs    = load_docs
links   = build_links(rows, docs)

if ARGV.include?('--check')
  ok = true
  FIELDS.each { |f| puts format('  weight %-11s %+.2f', f, weights[f]) }
  expect = { 'roi' => 0.30, 'strategic' => 0.20, 'impact' => 0.20,
             'urgency' => 0.15, 'culture' => 0.15, 'complexity' => -0.25 }
  expect.each do |f, v|
    next if (weights[f] - v).abs < 1e-9

    warn "FAIL: weight #{f} is #{weights[f]}, expected #{v}"
    ok = false
  end
  # Oracle: a FIXTURE, not a vault note. Verifies the arithmetic and the wiring
  # between weights and fields. Re-scoring a real ask must never fail this.
  fixture  = { 'roi' => 4, 'strategic' => 5, 'impact' => 5,
               'urgency' => 4, 'culture' => 3, 'complexity' => 3 }
  got = compute_overall(fixture, weights)
  if got == 3.5
    puts '  oracle    fixture (4,5,5,4,3,3) = 3.5 ✓'
  else
    warn "FAIL: fixture computed #{got}, expected 3.5"
    ok = false
  end

  # Unscored rows must stay unscored rather than silently totalling to 0.
  unless compute_overall(fixture.merge('culture' => nil), weights).nil?
    warn 'FAIL: a partially-scored row produced a number instead of nil'
    ok = false
  end

  # One page per note, so two notes must never slug to the same filename — that
  # would silently overwrite one entry's page with another's.
  hrefs = (rows + docs).map { |r| r[:href] }
  dupes = hrefs.select { |x| hrefs.count(x) > 1 }.uniq
  if dupes.empty?
    puts "  slugs     #{hrefs.size} unique page name(s) ✓"
  else
    warn "FAIL: duplicate page filenames: #{dupes.join(', ')}"
    ok = false
  end

  md_fails = Markdown.self_check
  if md_fails.empty?
    puts '  markdown  renderer assertions ✓'
  else
    md_fails.each { |f| warn "FAIL: #{f}" }
    ok = false
  end

  # Build the real pages. This is the assertion that matters: the check used to
  # verify arithmetic only, and passed on input that crashed the render.
  pages = build_pages(rows, docs, weights, links, 'check')
  puts "  render    #{pages.size} page(s) built without error ✓"

  # Read the hrefs out of the rendered HTML, not out of the hash that made them.
  bad = dangling_links(pages)
  if bad.empty?
    total = pages.values.map { |html| html.scan(/href="/).length }.reduce(0, :+)
    puts "  links     #{total} href(s) across #{pages.size} page(s) all resolve ✓"
  else
    bad.each { |b| warn "FAIL: dangling link #{b}" }
    ok = false
  end

  # Scores are the one note-derived value that reaches HTML without passing
  # through markdown.rb, so they get their own escaping assertion.
  hostile = '<img src=x onerror=alert(1)>'
  probe = ranked_table([{ name: 'probe', href: 'index.html', overall: nil,
                          scores: FIELDS.to_h { |f| [f, hostile] },
                          slot: hostile, status: hostile, logged: hostile }])
  if probe.include?(hostile)
    warn 'FAIL: a hostile score reached the ranking table unescaped'
    ok = false
  else
    puts '  escaping  hostile score / slot / status neutralised ✓'
  end

  # A quoted or non-numeric score used to unscore its row in silence.
  flagged = rows.reject { |r| r[:issues].empty? }
  if flagged.empty?
    puts '  fields    every score is an unquoted number ✓'
  else
    flagged.each { |r| r[:issues].each { |i| warn "FAIL: #{r[:name]}: #{i}" } }
    ok = false
  end

  scored = rows.count { |r| r[:overall] }
  puts "  data      #{rows.size} row(s), #{scored} scored, #{docs.size} reference page(s)"
  puts ok ? "OK (#{rows.size} rows, #{pages.size} pages)" : 'CHECK FAILED'
  exit(ok ? 0 : 1)
end

stamp = Time.now.strftime('%Y-%m-%d %H:%M %Z')
# Build first, then clear, then write. Clearing first meant any render error left
# the site directory empty rather than leaving the previous ranking in place.
pages = build_pages(rows, docs, weights, links, stamp)
dangling = dangling_links(pages)
abort "FATAL: dangling links, refusing to write: #{dangling.join(', ')}" unless dangling.empty?
clean_site
pages.each { |name, html| File.write(File.join(SITE, name), html) }
puts "wrote #{SITE} (#{rows.size} rows, #{pages.size} pages)"
