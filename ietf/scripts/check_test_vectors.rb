#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
VECTOR_ROOT = ROOT.join("test-vectors")

ALLOWED_DRAFTS = %w[
  draft-kavian-agent-enrollment-protocol-00
  draft-kavian-aep-oauth-session-credential-00
  draft-kavian-aep-api-key-session-credential-00
  draft-kavian-aep-basic-session-credential-00
].freeze

ALLOWED_CATEGORIES = %w[
  inspect
  client-assertion
  errors
  idempotency
  enroll
  status
  grant-revoke
  credentials/oauth-bearer
  credentials/api-key
  credentials/basic
].freeze

ALLOWED_ROLES = %w[agent service].freeze
ALLOWED_PROFILES = %w[core-http oauth-bearer api-key basic].freeze
ID_RE = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

errors = []

Dir[VECTOR_ROOT.join("**/*.json")].sort.each do |path|
  file = Pathname.new(path)
  rel = file.relative_path_from(VECTOR_ROOT).to_s

  begin
    data = JSON.parse(file.read)
  rescue JSON::ParserError => e
    errors << "#{rel}: invalid JSON: #{e.message}"
    next
  end

  %w[id title description drafts category applies_to profile input expected].each do |field|
    errors << "#{rel}: missing #{field}" unless data.key?(field)
  end
  next if errors.any? { |error| error.start_with?("#{rel}: missing") }

  id = data["id"]
  category = data["category"]
  expected_path = "#{category}/#{id}.json"

  errors << "#{rel}: id must be lowercase hyphenated" unless id.is_a?(String) && id.match?(ID_RE)
  errors << "#{rel}: category is not allowed" unless ALLOWED_CATEGORIES.include?(category)
  errors << "#{rel}: path must be #{expected_path}" unless rel == expected_path

  unless data["drafts"].is_a?(Array) && data["drafts"].all? { |draft| ALLOWED_DRAFTS.include?(draft) }
    errors << "#{rel}: drafts must list published AEP draft identifiers"
  end

  unless data["applies_to"].is_a?(Array) && data["applies_to"].all? { |role| ALLOWED_ROLES.include?(role) }
    errors << "#{rel}: applies_to must contain only known roles"
  end

  errors << "#{rel}: profile is not allowed" unless ALLOWED_PROFILES.include?(data["profile"])
  errors << "#{rel}: input must be an object" unless data["input"].is_a?(Hash)
  errors << "#{rel}: expected must be an object" unless data["expected"].is_a?(Hash)
end

if errors.empty?
  puts "Test vectors OK"
else
  warn errors.join("\n")
  exit 1
end
