#!/usr/bin/env ruby
# Renders the Pipeline Tracker to a static, self-contained HTML page.
#
# Weights are parsed OUT of Priority Ranking.base so the .base file stays the
# single source of truth. Change a weight in Obsidian and the site follows.
# Full rebuild every run, so deletions propagate (an unpublished retraction
# staying live was the top disclosure risk raised in review).
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

VAULT   = File.expand_path('..', __dir__) # this script lives in <vault>/.tools/
TRACKER = File.join(VAULT, 'S0', 'Internal Builds', 'Pipeline Tracker')
BASE    = File.join(TRACKER, 'Priority Ranking.base')
INTAKE  = File.join(TRACKER, 'Intake')
OUT     = File.join(VAULT, '.tracker-site', 'index.html')

FIELDS = %w[roi strategic impact urgency culture complexity].freeze
LABELS = {
  'roi' => 'Revenue ROI', 'strategic' => 'Strategic', 'impact' => 'Client Impact',
  'urgency' => 'Urgency', 'culture' => 'Culture', 'complexity' => 'Complexity'
}.freeze

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

# --- rows --------------------------------------------------------------------
def load_rows(weights)
  # .map{}.compact rather than filter_map — Ruby 2.6 compatibility
  Dir.glob(File.join(INTAKE, '*.md')).sort.map do |path|
    name = File.basename(path, '.md')
    # Templates live in <vault>/_Templates and are never read here. This guard
    # only catches a template copied into Intake/ but not yet renamed.
    next if name.start_with?('Executive Intake Entry')

    fm = YAML.safe_load(File.read(path).split(/^---\s*$/)[1].to_s,
                        permitted_classes: [Date], aliases: true) || {}
    next unless fm['tags'].to_a.include?('executive-intake')

    scores = FIELDS.to_h { |f| [f, fm[f]] }
    overall = compute_overall(scores, weights)
    { name: name, overall: overall, scores: scores,
      slot: fm['slot'], status: fm['status'].to_s,
      logged: fm['logged'].to_s, by: fm['logged_by'].to_s,
      verbatim: fm['verbatim'].to_s, interpreted: fm['interpreted'].to_s }
  end.compact
end

# --- html --------------------------------------------------------------------
def h(str) # macOS ships Ruby 2.6; no endless method defs
  CGI.escapeHTML(str.to_s)
end

def ranked_table(rows, empty = 'No scored items yet.')
  return %(<p class="empty">#{h(empty)}</p>) if rows.empty?

  head = ['Ask', 'Overall', 'Slot', 'Status', *FIELDS.map { |f| LABELS[f] }, 'Logged']
  body = rows.map do |r|
    cells = [h(r[:name]), format('%.2f', r[:overall]), h(r[:slot]), h(r[:status]),
             *FIELDS.map { |f| r[:scores][f] }, h(r[:logged])]
    tds = cells.each_with_index.map { |c, i| i == 1 ? %(<td class="score">#{c}</td>) : "<td>#{c}</td>" }
    "<tr>#{tds.join}</tr>"
  end
  <<~HTML
    <div class="scroll"><table>
      <thead><tr>#{head.map { |c| "<th>#{h(c)}</th>" }.join}</tr></thead>
      <tbody>#{body.join}</tbody>
    </table></div>
  HTML
end

def awaiting_table(rows)
  return '<p class="empty">Nothing awaiting scoring.</p>' if rows.empty?

  body = rows.map do |r|
    "<tr><td>#{h(r[:name])}</td><td>#{h(r[:verbatim])}</td><td>#{h(r[:logged])}</td><td>#{h(r[:by])}</td></tr>"
  end
  <<~HTML
    <div class="scroll"><table>
      <thead><tr><th>Ask</th><th>Verbatim</th><th>Logged</th><th>By</th></tr></thead>
      <tbody>#{body.join}</tbody>
    </table></div>
  HTML
end

def render(rows, weights, stamp)
  # Delivered work leaves the priority table. A finished project outranking live
  # work under a heading that says "Priority ranking" reads as "do this next" to
  # the one audience that matters, and nothing reviews this between here and them.
  # Partition on status, NOT slot: the shipped template ships slot Done with
  # status "Awaiting scoring" deliberately, so a slot-based split would route a
  # half-filled row into a table that formats an Overall it does not have yet.
  done     = %w[Shipped Done].freeze
  awaiting = rows.select { |r| r[:status] == 'Awaiting scoring' }
  shipped  = rows.select { |r| done.include?(r[:status]) }.sort_by { |r| -(r[:overall] || -99) }
  ranked   = rows.reject { |r| r[:status] == 'Awaiting scoring' || done.include?(r[:status]) }
                 .sort_by { |r| -(r[:overall] || -99) }
  formula  = FIELDS.map { |f| format('%+g·%s', weights[f], LABELS[f]) }.join(' ')

  <<~HTML
    <!doctype html>
    <html lang="en"><head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title>Pipeline Tracker — Priority Ranking</title>
    <style>
      :root{--bg:#fff;--fg:#1a1a1a;--dim:#666;--line:#e3e3e3;--head:#f6f6f6;--warn:#8a4b00;--warnbg:#fff6e8}
      @media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#ededed;--dim:#9a9a9a;--line:#2e2e2e;--head:#1f1f1f;--warn:#ffc27a;--warnbg:#2a1f10}}
      *{box-sizing:border-box}
      body{margin:0;padding:2rem 1.25rem;background:var(--bg);color:var(--fg);
           font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;overflow-x:hidden}
      main{max-width:1100px;margin:0 auto}
      h1{font-size:1.5rem;margin:0 0 .25rem}h2{font-size:1.05rem;margin:2rem 0 .6rem}
      .sub{color:var(--dim);margin:0 0 1.25rem}
      .banner{background:var(--warnbg);color:var(--warn);border:1px solid currentColor;
              border-radius:6px;padding:.6rem .8rem;font-weight:600;margin-bottom:1.5rem}
      .scroll{overflow-x:auto;-webkit-overflow-scrolling:touch}
      table{border-collapse:collapse;width:100%;font-size:14px}
      th,td{text-align:left;padding:.5rem .65rem;border-bottom:1px solid var(--line);white-space:nowrap}
      th{background:var(--head);font-weight:600;font-size:12.5px;text-transform:uppercase;letter-spacing:.03em}
      td:first-child,th:first-child{white-space:normal;min-width:15rem}
      .score{font-weight:700;font-variant-numeric:tabular-nums}
      .empty{color:var(--dim);font-style:italic}
      footer{margin-top:2.5rem;padding-top:1rem;border-top:1px solid var(--line);color:var(--dim);font-size:13px}
      code{font-size:12.5px}
    </style></head><body><main>
      <h1>Pipeline Tracker — Priority Ranking</h1>
      <p class="sub">Executive Intake asks, scored and ranked. Read-only view.</p>
      <div class="banner">Internal &amp; commercially confidential — do not forward or share this link.</div>
      <h2>Priority ranking</h2>
      #{ranked_table(ranked)}
      <h2>Awaiting scoring</h2>
      #{awaiting_table(awaiting)}
      <h2>Shipped</h2>
      <p class="sub">Delivered. Scores kept as a record of what shipped and what it cost &mdash; not a queue.</p>
      #{ranked_table(shipped, 'Nothing shipped yet.')}
      <footer>
        Generated #{h(stamp)} · #{ranked.size} ranked, #{shipped.size} shipped, #{awaiting.size} awaiting.<br>
        Overall = #{h(formula)} &nbsp;(each 1&ndash;5) &mdash; weights read live from
        <code>Priority Ranking.base</code>, so this page and the vault cannot disagree.
      </footer>
    </main></body></html>
  HTML
end

# --- main --------------------------------------------------------------------
weights = load_weights
rows    = load_rows(weights)

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

  scored = rows.count { |r| r[:overall] }
  puts "  data      #{rows.size} row(s), #{scored} scored"
  puts ok ? "OK (#{rows.size} rows)" : 'CHECK FAILED'
  exit(ok ? 0 : 1)
end

stamp = Time.now.strftime('%Y-%m-%d %H:%M %Z')
Dir.mkdir(File.dirname(OUT)) unless Dir.exist?(File.dirname(OUT))
File.write(OUT, render(rows, weights, stamp))
puts "wrote #{OUT} (#{rows.size} rows)"
