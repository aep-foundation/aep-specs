# frozen_string_literal: true

require "date"
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
REQUIRED_METADATA = %w[
  title
  abbrev
  docname
  category
  ipr
  submissiontype
  author
  normative
  informative
].freeze
REQUIRED_SECTIONS = [
  "# Introduction",
  "# IANA Considerations",
  "# Security Considerations",
  "# Privacy Considerations"
].freeze

def load_frontmatter(path, text)
  match = text.match(/\A---\n(.*?)\n\.\.\./m)
  raise "#{path}: missing YAML front matter terminated by ..." unless match

  YAML.safe_load(match[1], aliases: true, permitted_classes: [Date])
end

def basename_without_extension(path)
  File.basename(path, ".md")
end

drafts = ARGV
abort "usage: check_drafts.rb DRAFT.md [DRAFT.md ...]" if drafts.empty?

errors = []

drafts.each do |draft|
  path = Pathname.new(draft)
  errors << "#{draft}: file does not exist" unless path.file?
  next unless path.file?

  text = path.read
  metadata = load_frontmatter(draft, text)

  REQUIRED_METADATA.each do |field|
    errors << "#{draft}: missing #{field} metadata" unless metadata.key?(field)
  end

  docname = metadata["docname"]
  unless docname.is_a?(String) && docname.start_with?("draft-")
    errors << "#{draft}: docname must start with draft-"
  end

  expected_docname = basename_without_extension(draft)
  errors << "#{draft}: docname must match filename #{expected_docname}" unless docname == expected_docname

  unless metadata["author"].is_a?(Array) && metadata["author"].any?
    errors << "#{draft}: author metadata must be a non-empty array"
  end

  if metadata.key?("version")
    expected_version = expected_docname[/-(\d{2})\z/, 1]
    errors << "#{draft}: version must match filename suffix #{expected_version}" unless metadata["version"].to_s == expected_version
  end

  REQUIRED_SECTIONS.each do |section|
    errors << "#{draft}: missing #{section}" unless text.match?(/^#{Regexp.escape(section)}$/)
  end

  errors << "#{draft}: must not include hand-written # References section" if text.match?(/^# References$/)
  errors << "#{draft}: contains unresolved reference placeholder" if text.include?("Add normative and informative references")
  errors << "#{draft}: must reference RFC9110" unless text.include?("{{RFC9110}}")
end

core_path = ROOT.join("specs/core/draft-kavian-agent-enrollment-protocol-00.md")
if core_path.file?
  core = core_path.read
  errors << "#{core_path.relative_path_from(ROOT)}: missing DID-WEB normative reference" unless core.match?(/^  DID-WEB:$/)
end

if errors.empty?
  puts "Draft lint OK"
else
  warn errors.join("\n")
  exit 1
end
