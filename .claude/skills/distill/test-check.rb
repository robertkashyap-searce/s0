#!/usr/bin/env ruby
# Regression guard for the check.rb embedded in SKILL.md.
#
#   ruby .claude/skills/distill/test-check.rb
#
# check.rb is 192 lines of load-bearing logic living inside a markdown file.
# Nothing else in this repo would catch a syntax error, or an internal
# contradiction between two of its checks. One such contradiction shipped in
# the first draft: UKIND matched the phrase "what X means" while NEGCLAIM's
# closed vocabulary rejected the word "means", so every naturally-worded
# Undefined-terms row failed. That is the class of bug this file exists for.
#
# Asserts two things, both necessary:
#   1. the checker prints OK on a VALID minimal ingest  (no false positives —
#      a checker that red-flags correct work gets disabled by its operator)
#   2. each known defect fires its named check          (no false negatives —
#      a checker that never fires is decoration)
require 'fileutils'
require 'tmpdir'

SKILL = File.join(__dir__, 'SKILL.md')
abort "no SKILL.md beside this file" unless File.exist?(SKILL)

BLOCK = File.read(SKILL)[/^```ruby\n(.*?)^```$/m, 1] or
  abort "FAIL: no ```ruby block in SKILL.md — check.rb is gone or its fence changed"

LEDGER = 'Source — test (abc12345)'

def build(dir)
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p("#{dir}/nodes")
  FileUtils.mkdir_p("#{dir}/baseline")

  File.write("#{dir}/source.txt", <<~TXT)
    Pricing is 40k USD per year.
    We ship by Q3 if legal signs off.
  TXT

  # pre-existing vault basenames; must NOT contain the node this run creates
  File.write("#{dir}/linktable.txt", "S0 — Index\nFrontier Radar\n")

  File.write("#{dir}/ledger.md", <<~MD)
    ---
    tags:
      - brain
      - brain/source
    parent: "[[Brain — Index]]"
    ingested: 2026-08-14
    source_file: test.txt
    source_sha256_8: abc12345
    source_lines: 2
    ingest_status: complete
    ---
    # #{LEDGER}
    ## Coverage
    | Check | Result |
    |---|---|
    | Facts extracted | 2 |
    ## Fact inventory
    | # | L | Kind | Atomic fact | Anchor | Node |
    |---|---|---|---|---|---|
    | F001 | L1 | NUM | Pricing is 40k USD per year. | = | [[Pricing]] |
    | F002 | L2 | COND | IF legal signs off THEN we ship by Q3 | We ship by Q3 if legal signs off | [[Pricing]] |
    ## Excluded lines
    | Lines | Reason | Evidence |
    |---|---|---|
    ## Removals and substitutions
    | Line | Before | After | Ladder step |
    |---|---|---|---|
    ## Undefined terms
    | Term | Lines | Kind | What the dump says | What the dump does NOT say | Ladder step | Cause | Resolution ask | Vault match |
    |---|---|---|---|---|---|---|---|---|
    | USD | L1 | unspecified | USD attaches to the 40k figure | what USD means | 6 | undefined-in-source | What is the currency name? | — |
    ## Verification
    | Check | Result |
    |---|---|
    | check.rb | OK |
  MD

  File.write("#{dir}/nodes/Pricing.md", <<~MD)
    ---
    tags:
      - brain
      - brain/pricing
    parent: "[[Brain — Index]]"
    sources:
      - "[[#{LEDGER}]]"
    first_ingest: 2026-08-14
    last_ingest: 2026-08-14
    ---
    # Pricing
    ## Ingest — 2026-08-14 · [[#{LEDGER}]]
    ### Facts
    | # | Fact | L |
    |---|---|---|
    | F001 | Pricing is 40k USD per year. | L1 |
    | F002 | IF legal signs off THEN we ship by Q3 | L2 |
    ### Detail
    Pricing is 40k USD per year.
    IF legal signs off THEN we ship by Q3
    ### Undefined terms
    | Term | Lines | Kind | What the dump says | What the dump does NOT say |
    |---|---|---|---|---|
    | USD | L1 | unspecified | USD attaches to the 40k figure | what USD means |
    ### Open questions
    ### Connections
    - The dump ties the ship date to a legal sign-off. (F002)
  MD
end

def edit(path)
  File.write(path, yield(File.read(path)))
end

MUTATIONS = {
  'FACTTEXT' => ['fact string deleted from node body', lambda { |d|
    edit("#{d}/nodes/Pricing.md") { |t|
      t.sub("IF legal signs off THEN we ship by Q3\n### Undefined", '### Undefined')
       .sub("| F002 | IF legal signs off THEN we ship by Q3 | L2 |\n", '') } }],

  'PROSE' => ['authored sentence added to the body', lambda { |d|
    edit("#{d}/nodes/Pricing.md") { |t|
      t.sub('### Undefined terms',
            "This suggests the vendor is negotiating from strength.\n### Undefined terms") } }],

  'DEADLINK' => ['wikilink to a note that does not exist', lambda { |d|
    edit("#{d}/nodes/Pricing.md") { |t| t.sub('(F002)', '(F002) see [[Nonexistent Note]]') } }],

  'LINECOV' => ['a source line cited by no fact', lambda { |d|
    edit("#{d}/ledger.md") { |t| t.sub('| F002 | L2 | COND', '| F002 | L1 | COND') } }],

  'COLLIDE' => ['node basename already exists in the vault', lambda { |d|
    File.write("#{d}/linktable.txt", "S0 — Index\nFrontier Radar\nPricing\n") }],

  'DENSITY' => ['fact compressed to under half its cited span', lambda { |d|
    edit("#{d}/ledger.md") { |t|
      t.sub('| F002 | L2 | COND | IF legal signs off THEN we ship by Q3 |',
            '| F002 | L2 | COND | IF ok THEN ship |') } }],

  'PUBGATE' => ['site publish tag injected into frontmatter', lambda { |d|
    edit("#{d}/nodes/Pricing.md") { |t|
      t.sub('  - brain/pricing', "  - brain/pricing\n  - publish-to-site") } }],

  'APPEND' => ['existing node truncated instead of appended', lambda { |d|
    FileUtils.cp("#{d}/nodes/Pricing.md", "#{d}/baseline/Pricing.md")
    edit("#{d}/nodes/Pricing.md") { |t|
      t.sub("### Connections\n- The dump ties the ship date to a legal sign-off. (F002)\n", '') } }],
}

# Valid inputs that the checker WRONGLY REJECTED before 2026-08-16, each proving one
# fix. MUTATIONS prove the checker fires on defects; these prove it does not fire on
# correct work. A checker that red-flags valid work gets disabled by its operator,
# which is the same as having no checker at all.
REGRESSIONS = {
  'RANGEB bound "up to" is reachable' => lambda { |d|
    # DERIVE rejected "up" and "least", so two of RANGEB's five legal bound values
    # could never pass. SCAFF now carries both.
    edit("#{d}/ledger.md") { |t|
      t.sub('| F001 | L1 | NUM | Pricing is 40k USD per year. | = |',
            '| F001 | L1 | RANGE | Pricing is 40k USD per year; bound: up to | Pricing is 40k USD per year. |') }
    edit("#{d}/nodes/Pricing.md") { |t|
      t.gsub('Pricing is 40k USD per year.', 'Pricing is 40k USD per year; bound: up to') } },

  'US in an anchor is not first person' => lambda { |d|
    # PRONOUN matched \bus\b case-insensitively, so the country code in a patent
    # citation failed a fact containing no first person at all.
    File.write("#{d}/source.txt", "US Section 101 pricing is 40k USD per year.\nWe ship by Q3 if legal signs off.\n")
    edit("#{d}/ledger.md") { |t|
      t.sub('| F001 | L1 | NUM | Pricing is 40k USD per year. | = |',
            '| F001 | L1 | NUM | pricing is 40k USD per year | US Section 101 pricing is 40k USD per year. |') }
    edit("#{d}/nodes/Pricing.md") { |t|
      t.gsub('Pricing is 40k USD per year.', 'pricing is 40k USD per year') } },

  'an escaped pipe matches its own fact' => lambda { |d|
    # PROSE unpiped the fact side but not the body side, so a fact containing a
    # literal pipe could never match itself and always reported as authored prose.
    File.write("#{d}/source.txt", "Pricing is 40k USD per year | list price.\nWe ship by Q3 if legal signs off.\n")
    edit("#{d}/ledger.md") { |t|
      t.sub('| F001 | L1 | NUM | Pricing is 40k USD per year. | = |',
            '| F001 | L1 | NUM | Pricing is 40k USD per year \| list price. | = |') }
    edit("#{d}/nodes/Pricing.md") { |t|
      t.gsub('Pricing is 40k USD per year.', 'Pricing is 40k USD per year \| list price.') } },
}

fails = []

Dir.mktmpdir('distill-test') do |tmp|
  checker = "#{tmp}/check.rb"
  File.write(checker, BLOCK)

  unless system("ruby -c #{checker} > /dev/null 2>&1")
    puts `ruby -c #{checker} 2>&1`
    abort 'FAIL: check.rb does not parse'
  end
  puts 'ok   check.rb parses'

  valid = "#{tmp}/valid"
  build(valid)
  out = `ruby #{checker} #{valid} 2>&1`
  if $?.success? && out.include?('OK')
    puts 'ok   valid ingest passes clean'
  else
    fails << 'valid ingest was rejected'
    puts "FAIL valid ingest rejected:\n#{out}"
  end

  MUTATIONS.each do |check, (desc, mutate)|
    d = "#{tmp}/mut"
    build(d)
    mutate.call(d)
    out = `ruby #{checker} #{d} 2>&1`
    if out =~ /^(FAIL|WARN) #{check}\b/
      puts "ok   #{check} fires on #{desc}"
    else
      fails << "#{check} missed: #{desc}"
      puts "FAIL #{check} did not fire on #{desc}"
      puts "     got: #{out.lines.map(&:strip).reject(&:empty?).first(2).join(' / ')}"
    end
  end

REGRESSIONS.each do |label, apply|
  d = "#{tmp}/reg"
  build(d)
  apply.call(d)
  out = `ruby #{checker} #{d} 2>&1`
  if $?.success? && out.include?('OK')
    puts "ok   valid input accepted: #{label}"
  else
    fails << "regression: #{label}"
    puts "FAIL valid input rejected: #{label}"
    puts "     got: #{out.lines.map(&:strip).reject(&:empty?).first(3).join(' / ')}"
  end
end
end

if fails.empty?
  puts "\nOK — #{MUTATIONS.size + REGRESSIONS.size + 2} assertions passed"
else
  puts "\n#{fails.size} FAILED:"
  fails.each { |f| puts "  - #{f}" }
  exit 1
end
