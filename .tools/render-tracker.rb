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
DOCS = ['Scoring Rubric', 'Pipeline Tracker'].freeze

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
    fm = YAML.safe_load(raw.split(/^---[ \t]*$/)[1].to_s,
                        permitted_classes: [Date], aliases: true) || {}
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
  DOCS.map do |name|
    path = File.join(TRACKER, "#{name}.md")
    next unless File.exist?(path)

    { name: name, href: "#{slug(name)}.html", body: File.read(path) }
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

CSS = <<~CSS
  /* futurify.ai v0: two tones, 1px hairlines, no shadows, no third hue.
     Type tokens are theme-independent, so they sit in their own bare :root the
     way the design system splits typography.css from colors.css. The two colour
     rules below MUST declare the identical six keys — a token in only one block
     inherits the wrong value with no error. */
  :root{color-scheme:light dark;
        --display:"Space Grotesk","Space Grotesk Fallback",ui-sans-serif,system-ui,sans-serif;
        --body:"Manrope","Manrope Fallback",ui-sans-serif,system-ui,sans-serif;
        --mono:"IBM Plex Mono","IBM Plex Mono Fallback",ui-monospace,monospace}
  :root{--bg:#faf9f6;--fg:#111110;--dim:#6f6d66;--line:#dcd9d0;--codebg:#f2f0ea;--warn:#89601f}
  @media (prefers-color-scheme:dark){:root{--bg:#111110;--fg:#faf9f6;--dim:#9b9992;--line:#2e2d2a;--codebg:#1b1b19;--warn:#e1b66c}}
  *{box-sizing:border-box}
  body{margin:0;padding:2rem 1.25rem;background:var(--bg);color:var(--fg);
       font-family:var(--body);font-size:17px;line-height:1.62;overflow-x:hidden}
  main{max-width:1100px;margin:0 auto}
  h1,h2,h3,h4{font-family:var(--display)}
  h1{font-size:1.5rem;margin:0 0 .25rem;line-height:1.25}
  h2{font-size:1.05rem;margin:2rem 0 .6rem}
  h3{font-size:.98rem;margin:1.5rem 0 .5rem}
  h4{font-size:.92rem;margin:1.2rem 0 .4rem;color:var(--dim)}
  .sub{color:var(--dim);margin:0 0 1.25rem}
  a{color:var(--fg);text-decoration:underline;text-underline-offset:3px}
  a:hover{opacity:.62}
  :focus-visible{outline:2px solid var(--fg);outline-offset:3px}
  .crumb{display:inline-block;margin:0 0 1rem;font-size:13px}
  .banner{background:var(--fg);color:var(--bg);border-radius:2px;
          padding:.6rem .8rem;font-weight:600;margin-bottom:1.5rem}
  .scroll{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:.75rem 0}
  table{border-collapse:collapse;width:100%;font-size:14px}
  th,td{text-align:left;padding:.5rem .65rem;border-bottom:1px solid var(--line);vertical-align:top}
  thead th{font-family:var(--mono);font-weight:500;font-size:12.5px;text-transform:uppercase;
           letter-spacing:.12em;color:var(--dim);border-bottom:1px solid var(--line);white-space:nowrap}
  .ranking td,.ranking th{white-space:nowrap}
  .ranking td:first-child,.ranking th:first-child{white-space:normal;min-width:15rem}
  .score{font-weight:700;font-variant-numeric:tabular-nums}
  .empty{color:var(--dim);font-style:italic}
  blockquote{margin:1rem 0;padding:.1rem 1rem;border-left:3px solid var(--line)}
  blockquote.callout{border-left:3px solid var(--warn);padding:.6rem 1rem}
  .callout-title{font-weight:700;margin:.2rem 0;color:var(--warn)}
  code{background:var(--codebg);font-family:var(--mono);padding:.1em .35em;border-radius:2px;font-size:12.5px}
  pre{background:var(--codebg);padding:.75rem .9rem;border-radius:2px;overflow-x:auto}
  pre code{background:none;padding:0;font-size:12.5px;line-height:1.45}
  del{color:var(--dim)}
  ul,ol{padding-left:1.4rem}
  li{margin:.3rem 0}
  hr{border:0;border-top:1px solid var(--line);margin:1.75rem 0}
  .cards{display:flex;flex-wrap:wrap;gap:.4rem;margin:.75rem 0 1.25rem}
  .card{border:1px solid var(--line);border-radius:2px;padding:.35rem .6rem;font-size:12.5px;white-space:nowrap}
  .card b{font-variant-numeric:tabular-nums}
  footer{margin-top:2.5rem;padding-top:1rem;border-top:1px solid var(--line);color:var(--dim);font-size:13px}
CSS

BANNER = 'Internal &amp; commercially confidential. This site is public — treat anything written in an intake note as world-readable.'

def page(title, body, footer)
  <<~HTML
    <!doctype html>
    <html lang="en"><head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title>#{h(title)}</title>
    <style>#{CSS}</style></head><body><main>
    #{body}
    <footer>#{footer}</footer>
    </main></body></html>
  HTML
end

def ranked_table(rows, empty = 'No scored items yet.')
  return %(<p class="empty">#{h(empty)}</p>) if rows.empty?

  head = ['Ask', 'Overall', 'Slot', 'Status', *FIELDS.map { |f| LABELS[f] }, 'Logged']
  body = rows.map do |r|
    ask = %(<a href="#{r[:href]}">#{h(r[:name])}</a>)
    # Both the nil guard and h() on the scores are load-bearing. Without the
    # guard, an unscored row in this bucket aborts the whole render; without
    # h(), a non-numeric score reaches the highest-traffic page as raw markup —
    # and fixing only the guard is what would have exposed the second.
    overall = r[:overall] ? format('%.2f', r[:overall]) : '&mdash;'
    cells = [ask, overall, h(r[:slot]), h(r[:status]),
             *FIELDS.map { |f| h(r[:scores][f]) }, h(r[:logged])]
    tds = cells.each_with_index.map { |c, i| i == 1 ? %(<td class="score">#{c}</td>) : "<td>#{c}</td>" }
    "<tr>#{tds.join}</tr>"
  end
  <<~HTML
    <div class="scroll"><table class="ranking">
      <thead><tr>#{head.map { |c| "<th>#{h(c)}</th>" }.join}</tr></thead>
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
  # Built from the docs actually LOADED, never from the DOCS constant. Building
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
    #{Markdown.render(row[:body], links)}
  HTML
  page("#{row[:name]} — Pipeline Tracker", body,
       "Generated #{h(stamp)} · Executive Intake entry.")
end

def doc_page(doc, links, stamp)
  body = <<~HTML
    <a class="crumb" href="index.html">&larr; Priority ranking</a>
    <h1>#{h(doc[:name])}</h1>
    <div class="banner">#{BANNER}</div>
    #{Markdown.render(doc[:body], links)}
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
      next if target.start_with?('http', '#', 'mailto:')

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
