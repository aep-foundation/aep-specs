#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
VECTOR_ROOT = ROOT.join("test-vectors")

ALLOWED_DRAFTS = %w[
  draft-kavian-agent-enrollment-protocol-04
  draft-kavian-aep-claims-01
  draft-kavian-aep-oauth-session-credential-04
  draft-kavian-aep-api-key-session-credential-04
  draft-kavian-aep-basic-session-credential-04
  draft-kavian-aep-did-web-identity-method-00
  draft-kavian-aep-platform-hosted-identity-01
].freeze

ALLOWED_CATEGORIES = %w[
  caching
  claims
  inspect
  openapi
  client-assertion
  errors
  idempotency
  enroll
  status
  grant-revoke
  platform
  protected-resource
  credentials/oauth-bearer
  credentials/api-key
  credentials/basic
].freeze

ALLOWED_ROLES = %w[agent platform service].freeze
ALLOWED_PROFILES = %w[core-http claims platform-hosted-identity oauth-bearer api-key basic].freeze
ALLOWED_EXPECTATIONS = %w[required optional unsupported].freeze
ID_RE = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

errors = []

Dir[VECTOR_ROOT.join("**/*.json")].sort.each do |path|
  file = Pathname.new(path)
  rel = file.relative_path_from(VECTOR_ROOT).to_s
  next if rel == "index.json"

  begin
    data = JSON.parse(file.read)
  rescue JSON::ParserError => e
    errors << "#{rel}: invalid JSON: #{e.message}"
    next
  end

  %w[id title description drafts category applicability input expected].each do |field|
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

  applicability = data["applicability"]
  unless applicability.is_a?(Hash) && applicability.keys == ALLOWED_ROLES
    errors << "#{rel}: applicability must classify agent, platform, and service in alphabetical order"
    next
  end
  executable_profiles = applicability.filter_map do |role, rule|
    unless rule.is_a?(Hash) && ALLOWED_EXPECTATIONS.include?(rule["expectation"])
      errors << "#{rel}: #{role} applicability expectation is invalid"
      next
    end
    expected_fields = rule["expectation"] == "unsupported" ? %w[expectation] : %w[expectation profile]
    errors << "#{rel}: #{role} applicability fields are invalid" unless rule.keys.sort == expected_fields
    if rule["expectation"] != "unsupported" && !ALLOWED_PROFILES.include?(rule["profile"])
      errors << "#{rel}: #{role} applicability profile is invalid"
    end
    rule["profile"] unless rule["expectation"] == "unsupported"
  end
  errors << "#{rel}: at least one role must be executable" if executable_profiles.empty?

  if data["drafts"].include?("draft-kavian-aep-claims-01") && executable_profiles.any? { |profile| profile != "claims" }
    errors << "#{rel}: Claims draft vectors must use the claims profile"
  elsif executable_profiles.include?("claims") && !data["drafts"].include?("draft-kavian-aep-claims-01")
    errors << "#{rel}: claims profile vectors must cover the Claims draft"
  end
  if file.read.include?("did:web") && !data["drafts"].include?("draft-kavian-aep-did-web-identity-method-00")
    errors << "#{rel}: did:web vectors must cover the did:web identity-method draft"
  end
  errors << "#{rel}: input must be an object" unless data["input"].is_a?(Hash)
  errors << "#{rel}: expected must be an object" unless data["expected"].is_a?(Hash)
end

if errors.empty?
  puts "Test vectors OK"
else
  warn errors.join("\n")
  exit 1
end
