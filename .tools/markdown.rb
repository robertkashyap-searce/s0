# frozen_string_literal: true

# Minimal Markdown → HTML for the note subset this vault actually uses.
#
# Why hand-rolled: no gems are available. CLAUDE.md pins this to Ruby 2.6 system
# Ruby with no bundler, and rules out Python/PyYAML. `gem list` confirms no
# markdown gem is present. Adding one in CI but not locally would give the two
# runners different renderers — the same drift that parsing weights out of the
# .base file exists to prevent.
#
# Supported, because it is what the notes contain: ATX headings, fenced code,
# pipe tables, blockquotes and Obsidian [!callouts], "-" and "1." lists, ---
# rules, **bold** *em* `code` ~~del~~, [[wikilinks]] with |aliases, [text](url).
# Anything else degrades to escaped text rather than breaking the page.
#
# SAFETY: note content is HTML-escaped BEFORE any transform that emits a tag, so
# nothing in a note can inject markup. Tags are inserted into already-escaped
# text. Code spans and links are stashed behind <n> placeholders so their
# contents receive no further markup — that placeholder cannot collide with
# content, because escaping has already removed every < and > from it.
#
# Ruby 2.6-compatible: no filter_map, no endless method definitions.

require 'cgi'

module Markdown
  MAX_UNSTASH = 8 # placeholder nesting depth; links inside links inside code

  # --- entry point ------------------------------------------------------------
  # links: { "Note Basename" => "target.html" }. A wikilink whose target is not
  # in the map renders as plain text, deliberately: the published site is an
  # allowlist, and a link to a page we chose not to publish must not exist.
  def self.render(src, links = {})
    # Normalise line endings once, here, rather than tolerating \r in every
    # block and inline pattern downstream. A CRLF note otherwise carries a
    # trailing \r into every heading, cell and list item.
    normalised = src.to_s.gsub(/\r\n?/, "\n")
    blocks(strip_frontmatter(normalised).split("\n", -1), links)
  end

  # The fence pattern must match the one render-tracker.rb uses to PARSE the
  # frontmatter. It used to be start_with?("---\n") while the loader split on
  # /^---\s*$/, whose \s* matches \r. A CRLF-saved note therefore parsed as a
  # valid intake row while its frontmatter was never stripped — publishing the
  # whole YAML block, including the verbatim executive quote and logged_by, as
  # page text. Two parsers of one fence must agree.
  def self.strip_frontmatter(src)
    s = src.to_s
    return s unless s =~ /\A---[ \t]*\r?\n/

    parts = s.split(/^---[ \t]*\r?$/, 3)
    parts.length >= 3 ? parts[2].to_s.sub(/\A\r?\n/, '') : s
  end

  # --- block level ------------------------------------------------------------
  def self.blocks(lines, links)
    out = []
    i = 0
    while i < lines.length
      line = lines[i].to_s
      if line.strip.empty?
        i += 1
      elsif fence?(line)
        i = emit_fence(lines, i, out)
      elsif table?(lines, i)
        i = emit_table(lines, i, out, links)
      elsif (m = line.match(/\A(\#{1,6})\s+(.*)\z/))
        level = m[1].length
        out << "<h#{level}>#{inline(m[2], links)}</h#{level}>"
        i += 1
      elsif rule?(line)
        out << '<hr>'
        i += 1
      elsif line.start_with?('>')
        i = emit_quote(lines, i, out, links)
      elsif line =~ /\A\s*[-*]\s+\S/
        i = emit_list(lines, i, out, links, :ul)
      elsif line =~ /\A\s*\d+\.\s+\S/
        i = emit_list(lines, i, out, links, :ol)
      else
        i = emit_paragraph(lines, i, out, links)
      end
    end
    out.join("\n")
  end

  def self.fence?(line)
    !(line.to_s.strip =~ /\A`{3,}/).nil?
  end

  def self.rule?(line)
    !(line.to_s.strip =~ /\A(?:-{3,}|\*{3,}|_{3,})\z/).nil?
  end

  # True where a new block starts, so paragraphs and list items stop absorbing.
  def self.boundary?(lines, i)
    line = lines[i].to_s
    line.strip.empty? || fence?(line) || rule?(line) || line.start_with?('>') ||
      table?(lines, i) || !(line =~ /\A\#{1,6}\s/).nil? ||
      !(line =~ /\A\s*[-*]\s+\S/).nil? || !(line =~ /\A\s*\d+\.\s+\S/).nil?
  end

  def self.emit_fence(lines, i, out)
    lang = lines[i].to_s.strip.sub(/\A`{3,}/, '').strip
    i += 1
    buf = []
    while i < lines.length && lines[i].to_s.strip !~ /\A`{3,}\s*\z/
      buf << lines[i]
      i += 1
    end
    i += 1 # consume the closing fence; running off the end is harmless
    cls = lang.empty? ? '' : %( class="lang-#{CGI.escapeHTML(lang)}")
    out << %(<pre#{cls}><code>#{CGI.escapeHTML(buf.join("\n"))}</code></pre>)
    i
  end

  def self.emit_paragraph(lines, i, out, links)
    buf = []
    while i < lines.length && !boundary?(lines, i)
      buf << lines[i].to_s.strip
      i += 1
    end
    out << "<p>#{inline(buf.join(' '), links)}</p>" unless buf.empty?
    i
  end

  def self.emit_list(lines, i, out, links, kind)
    tag = kind == :ul ? 'ul' : 'ol'
    re  = kind == :ul ? /\A\s*[-*]\s+(.*)\z/ : /\A\s*\d+\.\s+(.*)\z/
    out << "<#{tag}>"
    while i < lines.length && (m = lines[i].to_s.match(re))
      item = m[1]
      i += 1
      # Absorb hard-wrapped continuation lines: indented, non-blank, not a new block.
      while i < lines.length && lines[i].to_s =~ /\A\s+\S/ && !boundary?(lines, i)
        item = "#{item} #{lines[i].to_s.strip}"
        i += 1
      end
      out << "<li>#{inline(item, links)}</li>"
    end
    out << "</#{tag}>"
    i
  end

  def self.emit_quote(lines, i, out, links)
    buf = []
    while i < lines.length && lines[i].to_s.start_with?('>')
      buf << lines[i].to_s.sub(/\A>\s?/, '')
      i += 1
    end
    cls = 'quote'
    title = nil
    if buf.first.to_s =~ /\A\[!(\w+)\]\s*(.*)\z/
      cls = "callout callout-#{Regexp.last_match(1).downcase}"
      title = Regexp.last_match(2)
      title = nil if title.to_s.strip.empty?
      buf.shift
    end
    out << %(<blockquote class="#{cls}">)
    out << %(<p class="callout-title">#{inline(title, links)}</p>) if title
    out << blocks(buf, links) # lists and tables nested in a quote still render
    out << '</blockquote>'
    i
  end

  # --- tables -----------------------------------------------------------------
  # A table is a row containing | followed by a separator row of only -, : and |.
  def self.table?(lines, i)
    lines[i].to_s.include?('|') && sep_row?(lines[i + 1])
  end

  def self.sep_row?(line)
    s = line.to_s
    return false unless s.include?('-') && s.include?('|')

    c = cells(s)
    !c.empty? && c.all? { |x| !(x =~ /\A:?-+:?\z/).nil? }
  end

  # Cells are split BEFORE any inline transform, by an explicit scanner rather
  # than String#split, because a pipe inside [[Target|Alias]] is an alias
  # separator and not a cell boundary. Splitting on raw | turns one cell into two
  # and shifts every subsequent column. Escaped \| is also honoured.
  def self.cells(line)
    s = line.to_s.strip
    s = s[1..-1].to_s if s.start_with?('|')
    s = s[0..-2].to_s if s.end_with?('|')
    # Honour bracket protection only when the brackets actually balance on this
    # line. An unclosed [[ would otherwise leave depth > 0 forever, swallow every
    # remaining pipe, and collapse the row into one cell — which emit_table then
    # pads into a structurally perfect table with silently blank columns. Correct
    # column counts matter more than protecting a malformed link.
    protect = s.scan('[[').length == s.scan(']]').length
    out = []
    buf = String.new # frozen_string_literal is on; this needs to be mutable
    depth = 0
    i = 0
    while i < s.length
      pair = s[i, 2]
      if protect && pair == '[['
        depth += 1
        buf << pair
        i += 2
      elsif protect && pair == ']]' && depth > 0
        depth -= 1
        buf << pair
        i += 2
      elsif s[i] == '\\' && s[i + 1] == '|'
        buf << '|'
        i += 2
      elsif s[i] == '|' && depth.zero?
        out << buf.strip
        buf = String.new
        i += 1
      else
        buf << s[i]
        i += 1
      end
    end
    out << buf.strip
    out
  end

  def self.emit_table(lines, i, out, links)
    head = cells(lines[i])
    i += 2 # header row + separator row
    body = []
    while i < lines.length && lines[i].to_s.include?('|') && !lines[i].to_s.strip.empty?
      body << cells(lines[i])
      i += 1
    end
    width = head.length
    rows = body.map do |row|
      r = row.dup
      # Pad short rows, truncate long ones: the emitted table can then never
      # have a cell-count mismatch against its header.
      r << '' while r.length < width
      r = r[0, width] if r.length > width
      '<tr>' + r.map { |c| "<td>#{inline(c, links)}</td>" }.join + '</tr>'
    end
    out << '<div class="scroll"><table>'
    out << '<thead><tr>' + head.map { |c| "<th>#{inline(c, links)}</th>" }.join + '</tr></thead>'
    out << "<tbody>#{rows.join}</tbody>"
    out << '</table></div>'
    i
  end

  # --- inline -----------------------------------------------------------------
  def self.inline(text, links = {})
    s = CGI.escapeHTML(text.to_s)
    stash = []

    # Code spans first: nothing inside them may receive further markup.
    s = s.gsub(/`([^`]+)`/) { stash_it(stash, "<code>#{Regexp.last_match(1)}</code>") }

    # [[Target]] / [[Target|Alias]] — unresolved targets become plain text.
    # The character classes exclude "[" deliberately. When the target class
    # permitted it, a single unclosed [[ earlier on the line matched forward
    # across arbitrary prose and terminated at the NEXT wikilink's alias pipe;
    # the bogus target then missed the allowlist and the unresolved branch emitted
    # only the label, silently deleting every character in between.
    s = s.gsub(/\[\[([^\]\[|]+)(?:\|([^\]\[]+))?\]\]/) do
      target = Regexp.last_match(1).strip
      label  = (Regexp.last_match(2) || target).strip
      href   = links[target]
      stash_it(stash, href ? %(<a href="#{href}">#{label}</a>) : label)
    end

    # [text](url) — http(s), a fragment, or a local .html only. Anything else
    # (javascript:, data:, file:) degrades to its label rather than linking.
    s = s.gsub(/\[([^\]]+)\]\(([^)\s]+)\)/) do
      label = Regexp.last_match(1)
      url   = Regexp.last_match(2)
      # A URL must not contain a stash placeholder. Wikilinks are stashed BEFORE
      # links, and a stashed anchor holds raw, renderer-emitted quotes and angle
      # brackets. Left unchecked, [text](<0>) passed the scheme test on its
      # prefix and unstash then dropped a raw-quoted <a …> inside href="…".
      # A legitimate URL never contains "<" — the content was escaped already.
      safe = (url =~ /[<>]/).nil? &&
             !(url =~ %r{\A(?:https?://[^\s<>]+|\#[^\s<>]+|[\w.\-]+\.html)\z}).nil?
      stash_it(stash, safe ? %(<a href="#{CGI.escapeHTML(url)}" rel="noopener">#{label}</a>) : label)
    end

    s = s.gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
    s = s.gsub(/(?<!\*)\*([^*\n]+)\*(?!\*)/, '<em>\1</em>')
    s = s.gsub(/~~([^~]+)~~/, '<del>\1</del>')

    unstash(s, stash)
  end

  # A stashed fragment can itself contain a placeholder — a code span inside a
  # link label, for instance — and gsub never re-scans its own replacement. So
  # substitute repeatedly until nothing is left, rather than once.
  def self.unstash(str, stash)
    s = str
    MAX_UNSTASH.times do
      break unless s =~ /<(\d+)>/

      s = s.gsub(/<(\d+)>/) { stash[Regexp.last_match(1).to_i].to_s }
    end
    s
  end

  def self.stash_it(stash, html)
    stash << html
    "<#{stash.size - 1}>"
  end

  # --- self-check -------------------------------------------------------------
  # Returns failure strings; empty means healthy. Called from
  # render-tracker.rb --check, so CI catches a regression here.
  def self.self_check
    fails = []
    want = lambda do |label, got, expected|
      fails << "markdown #{label}: got #{got.inspect}, want #{expected.inspect}" unless got == expected
    end

    want.call('escapes tags', inline('<script>alert(1)</script>'),
              '&lt;script&gt;alert(1)&lt;/script&gt;')
    want.call('escapes attribute quotes', inline('a" onmouseover="x'),
              'a&quot; onmouseover=&quot;x')
    want.call('bold', inline('**x**'), '<strong>x</strong>')
    want.call('em', inline('*x*'), '<em>x</em>')
    want.call('del', inline('~~x~~'), '<del>x</del>')
    want.call('code span not further marked up', inline('`**x**`'), '<code>**x**</code>')
    want.call('wikilink resolves', inline('[[A]]', 'A' => 'a.html'),
              '<a href="a.html">A</a>')
    want.call('wikilink alias resolves', inline('[[A|B]]', 'A' => 'a.html'),
              '<a href="a.html">B</a>')
    want.call('unresolved wikilink is plain text', inline('[[Nope]]'), 'Nope')
    # Assert the safety property, not an exact string: a URL containing parens
    # leaves a cosmetic ")" behind, which is harmless. What matters is that no
    # anchor is emitted for a scheme the allowlist does not cover.
    ['[x](javascript:alert(1))', '[x](data:text/html,gotcha)',
     '[x](vbscript:msgbox)', '[x](file:///etc/passwd)',
     '[x](JaVaScRiPt:alert(1))'].each do |bad|
      got = inline(bad)
      fails << "markdown link safety: #{bad} produced an anchor -> #{got}" if got.include?('<a')
    end
    want.call('safe relative .html link', inline('[x](a.html)'),
              '<a href="a.html" rel="noopener">x</a>')
    want.call('safe https link', inline('[x](https://example.com)'),
              '<a href="https://example.com" rel="noopener">x</a>')

    # Nested placeholder: a code span inside a link label. A single-pass restore
    # leaks the inner placeholder into the page as literal "<0>".
    want.call('nested placeholders fully restored',
              inline('[`x`](a.html)'),
              '<a href="a.html" rel="noopener"><code>x</code></a>')

    want.call('cell keeps alias pipe', cells('| [[A|B]] | c |'), ['[[A|B]]', 'c'])
    want.call('cell honours escaped pipe', cells('| a \\| b | c |'), ['a | b', 'c'])
    want.call('separator row detected', sep_row?('|---|:--:|'), true)
    want.call('plain pipe row is not a separator', sep_row?('| a | b |'), false)
    want.call('heading', render("## Hi\n"), '<h2>Hi</h2>')
    want.call('rule', render("---\n"), '<hr>')

    table = render("| a | b |\n|---|---|\n| [[A|B]] | 2 |\n", 'A' => 'a.html')
    want.call('table cell count', table.scan('<td>').length, 2)
    fails << 'markdown table: alias link missing' unless table.include?('<a href="a.html">B</a>')

    short = render("| a | b |\n|---|---|\n| only |\n")
    want.call('short row padded to header width', short.scan('<td>').length, 2)

    fenced = render("```mermaid\nflowchart LR\n  A --> B\n```\n")
    fails << 'markdown fence: mermaid not emitted as preformatted text' unless
      fenced.start_with?('<pre class="lang-mermaid"><code>')
    fails << 'markdown fence: content not escaped' unless fenced.include?('A --&gt; B')

    callout = render("> [!warning] Careful\n> body text\n")
    fails << 'markdown callout: class missing' unless callout.include?('callout-warning')
    fails << 'markdown callout: title missing' unless callout.include?('Careful')

    # --- regressions found by adversarial review; each of these once shipped ---

    # CRLF frontmatter must strip, or the whole YAML block (verbatim executive
    # quote, logged_by) renders as page body.
    crlf = render("---\r\nverbatim: secret quote\r\nlogged_by: A Person\r\n---\r\n\r\n## Body\r\n")
    fails << 'markdown CRLF frontmatter not stripped' if crlf.include?('secret quote')
    fails << 'markdown CRLF body not rendered' unless crlf.include?('<h2>Body</h2>')
    lf = render("---\nverbatim: secret quote\n---\n\n## Body\n")
    fails << 'markdown LF frontmatter not stripped' if lf.include?('secret quote')

    # An unclosed [[ must not swallow the prose between it and the next wikilink.
    eaten = inline('start [[ oops middle prose [[A|B]] end', 'A' => 'a.html')
    %w[start middle prose end].each do |word|
      fails << "markdown unclosed [[ deleted the word #{word.inspect}" unless eaten.include?(word)
    end

    # An unbalanced [[ must not collapse a table row into one cell.
    fails << 'markdown unbalanced [[ collapsed a row' unless
      cells('| a [[ b | c | d |').length == 3

    # A stashed placeholder must never be adopted as a link URL.
    injected = inline('[click]([[A]])', 'A' => 'a.html')
    fails << "markdown placeholder adopted as href: #{injected}" if injected =~ /href="[^"]*<|href="\d/

    fails
  end
end
