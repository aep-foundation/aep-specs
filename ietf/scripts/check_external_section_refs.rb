# frozen_string_literal: true

PATTERN = /Section\s+\d+(?:\.\d+)*\s+of\s+\{\{I-D\.[^}]+\}\}/

drafts = ARGV
abort "usage: check_external_section_refs.rb DRAFT.md [DRAFT.md ...]" if drafts.empty?

errors = []

drafts.each do |draft|
  File.read(draft).scan(PATTERN) do |match|
    errors << "#{draft}: hardcoded external section reference: #{match}"
  end
end

if errors.empty?
  puts "External section references OK"
else
  warn errors.join("\n")
  warn "\nUse stable cross-references or section-agnostic document references instead."
  exit 1
end
