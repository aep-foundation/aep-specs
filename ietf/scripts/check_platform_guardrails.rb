#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

PLATFORM_PATHS = [
  ROOT.join("specs/platforms"),
  ROOT.join("test-vectors/platform"),
  ROOT.parent.join("artifacts/draft-kavian-aep-platform-hosted-identity-01.xml"),
  ROOT.parent.join("artifacts/draft-kavian-aep-platform-hosted-identity-01.txt"),
  ROOT.parent.join("artifacts/draft-kavian-aep-platform-hosted-identity-01.html")
].freeze

errors = []

PLATFORM_PATHS.each do |path|
  next unless path.exist?

  files = path.directory? ? path.glob("**/*").select(&:file?) : [path]
  files.each do |file|
    file.each_line.with_index(1) do |line, line_number|
      next unless line.match?(/"(?:key_id|kid)"\s*:\s*"did:[^"]+#/)

      rel = file.relative_path_from(ROOT.parent)
      errors << "#{rel}:#{line_number}: Platform Hosted Identity key_id/kid values must not use DID fragments"
    end
  end
end

if errors.empty?
  puts "Platform guardrails OK"
else
  warn errors.join("\n")
  exit 1
end
