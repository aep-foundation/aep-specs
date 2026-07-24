#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "date"
require "ipaddr"
require "time"

ROOT = Pathname.new(__dir__).join("..").expand_path
SCHEMA_ROOT = ROOT.join("schemas")
VECTOR_ROOT = ROOT.join("test-vectors")

SCHEMA_TARGETS = [
  ["claims/person-contact-catalog.json", "claim-values.schema.json", %w[expected]],
  ["claims/forward-compatible-address.json", "claim-values.schema.json", %w[input claim_values]],
  ["claims/minimal-email.json", "claim-values.schema.json", %w[input claim_values]],
  ["claims/quoted-email.json", "claim-values.schema.json", %w[input claim_values]],
  ["client-assertion/enroll-claims.json", "client-assertion-claims.schema.json", %w[expected]],
  ["protected-resource/authenticate-assertion.json", "client-assertion-claims.schema.json", %w[expected claims]],
  ["protected-resource/authorization-carriers.json", "protected-resource-authorization.schema.json", %w[expected dedicated_jwt]],
  ["protected-resource/authorization-carriers.json", "protected-resource-authorization.schema.json", %w[expected dedicated_bearer]],
  ["protected-resource/authorization-carriers.json", "protected-resource-authorization.schema.json", %w[expected dedicated_basic]],
  ["inspect/minimal-http.json", "inspect-document.schema.json", %w[expected]],
  ["inspect/claims-catalog-advertisement.json", "inspect-document.schema.json", %w[expected]],
  ["openapi/security-inheritance.json", "openapi-aep-security-scheme.schema.json", %w[input security_scheme]],
  ["enroll/request-minimal.json", "enroll-request.schema.json", %w[input]],
  ["enroll/request-claims-catalog.json", "enroll-request.schema.json", %w[input]],
  ["enroll/request-claims-catalog.json", "claim-values.schema.json", %w[input claims]],
  ["enroll/response-active.json", "enroll-response.schema.json", %w[expected body]],
  ["enroll/response-pending-verification-owner-action.json", "enroll-response.schema.json", %w[expected body]],
  ["status/response-active.json", "status-response.schema.json", %w[expected body]],
  ["status/response-pending-requirements.json", "status-response.schema.json", %w[expected body]],
  ["grant-revoke/grant-request-oauth-bearer.json", "grant-request.schema.json", %w[expected body]],
  ["grant-revoke/revoke-request-oauth-bearer.json", "revoke-request.schema.json", %w[expected body]],
  ["grant-revoke/revoke-request-all-grant-types.json", "revoke-request.schema.json", %w[expected body]],
  ["grant-revoke/revoke-response-empty.json", "revoke-response.schema.json", %w[expected body]],
  ["errors/not-recognized-problem.json", "problem.schema.json", %w[expected body]],
  ["errors/verification-pending-problem.json", "problem.schema.json", %w[expected body]],
  ["errors/requirements-unmet-problem.json", "problem.schema.json", %w[expected body]],
  ["idempotency/enroll-conflict.json", "idempotency-metadata.schema.json", %w[input]],
  ["idempotency/enroll-conflict.json", "problem.schema.json", %w[expected body]],
  ["credentials/oauth-bearer/grant-response.json", "oauth-bearer-grant-response.schema.json", %w[expected]],
  ["credentials/api-key/grant-response.json", "api-key-grant-response.schema.json", %w[expected]],
  ["credentials/basic/grant-response.json", "basic-grant-response.schema.json", %w[expected]],
  ["platform/discovery.json", "platform-discovery.schema.json", %w[expected]],
  ["platform/provision-request.json", "platform-provision-request.schema.json", %w[input]],
  ["platform/provision-response.json", "platform-agent-identity.schema.json", %w[expected]],
  ["platform/list-response.json", "platform-agent-identity-list-response.schema.json", %w[expected]],
  ["platform/lifecycle-request.json", "platform-lifecycle-request.schema.json", %w[input]],
  ["platform/lifecycle-response.json", "platform-lifecycle-response.schema.json", %w[expected]],
  ["platform/sign-request.json", "platform-sign-request.schema.json", %w[input]],
  ["platform/sign-response.json", "platform-sign-response.schema.json", %w[expected]],
  ["platform/sign-response-pending.json", "platform-sign-response.schema.json", %w[expected]],
  ["platform/verification-request.json", "platform-verification-request.schema.json", %w[input]],
  ["platform/verification-response-recognized.json", "platform-verification-response.schema.json", %w[expected]],
  ["platform/verification-response-unrecognized.json", "platform-verification-response.schema.json", %w[expected]]
].freeze

CLAIM_SCHEMA_CASES = %w[
  claims/invalid-address.json
  claims/invalid-birthdate.json
  claims/invalid-country-shape.json
  claims/invalid-email-domain.json
  claims/invalid-email-dot-string.json
  claims/invalid-email-format.json
  claims/invalid-empty-email.json
  claims/invalid-mobile.json
  claims/invalid-value-type.json
].freeze

def load_json(path)
  JSON.parse(Pathname.new(path).read)
rescue JSON::ParserError => e
  raise "#{path}: invalid JSON: #{e.message}"
end

def dig_path(data, path)
  path.reduce(data) do |current, segment|
    raise "missing path #{path.join('.')}" unless current.is_a?(Hash) && current.key?(segment)

    current[segment]
  end
end

def type_valid?(value, expected)
  case expected
  when "object" then value.is_a?(Hash)
  when "array" then value.is_a?(Array)
  when "string" then value.is_a?(String)
  when "integer" then value.is_a?(Integer)
  when "number" then value.is_a?(Numeric)
  when "boolean" then value == true || value == false
  when "null" then value.nil?
  else true
  end
end

def mailbox_parts(value)
  return value.split("@", -1) if !value.start_with?('"') && value.count("@") == 1
  return nil unless value.start_with?('"')

  escaped = false
  value.each_char.with_index do |character, index|
    next if index.zero?

    if escaped
      escaped = false
    elsif character == "\\"
      escaped = true
    elsif character == '"'
      return nil unless value[index + 1] == "@"

      return [value[0..index], value[(index + 2)..]]
    end
  end
  nil
end

def valid_quoted_local_part?(value)
  return false unless value.length >= 2 && value.end_with?('"')

  index = 1
  while index < value.length - 1
    code = value.getbyte(index)
    if code == 92
      index += 1
      return false if index >= value.length - 1

      escaped = value.getbyte(index)
      return false unless escaped.between?(32, 126)
    elsif !code.between?(32, 33) && !code.between?(35, 91) && !code.between?(93, 126)
      return false
    end
    index += 1
  end
  true
end

def valid_mailbox_domain?(value)
  if value.start_with?("[") || value.end_with?("]")
    return false unless value.start_with?("[") && value.end_with?("]")

    literal = value[1...-1]
    ipv6 = literal.start_with?("IPv6:")
    address = ipv6 ? literal.delete_prefix("IPv6:") : literal
    begin
      return true if IPAddr.new(address).to_s
    rescue IPAddr::InvalidAddressError
      # Fall through to the registered general-address-literal syntax.
    end
    return false if ipv6

    tag, content = literal.split(":", 2)
    return false unless tag&.match?(/\A[A-Za-z0-9-]*[A-Za-z0-9]\z/) && !content.to_s.empty?

    return content.bytes.all? { |byte| byte.between?(33, 90) || byte.between?(94, 126) }
  end

  value.split(".", -1).all? do |label|
    label.bytesize <= 63 &&
      label.match?(/\A[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\z/)
  end
end

def valid_mailbox?(value)
  local, domain = mailbox_parts(value)
  return false unless local && domain && !local.empty? && !domain.empty?
  return false if local.bytesize > 64 || domain.bytesize > 255

  local_valid =
    if local.start_with?('"')
      valid_quoted_local_part?(local)
    else
      atom = /[A-Za-z0-9!#$%&'*+\-\/=?^_`{|}~]+/
      local.match?(/\A#{atom}(?:\.#{atom})*\z/)
    end
  local_valid && valid_mailbox_domain?(domain)
end

def validate_format(value, format, location, errors)
  return unless value.is_a?(String)

  case format
  when "date"
    parsed = Date.iso8601(value)
    raise ArgumentError unless parsed.iso8601 == value
  when "date-time"
    Time.iso8601(value)
  when "email"
    raise ArgumentError unless valid_mailbox?(value)
  end
rescue ArgumentError
  description = format == "email" ? "RFC 5321 Mailbox" : "RFC 3339 #{format}"
  errors << "#{location}: must be #{description}"
end

def validate_schema(schema, value, location, errors)
  if schema.key?("oneOf")
    matches = schema["oneOf"].count do |candidate|
      candidate_errors = []
      validate_schema(candidate, value, location, candidate_errors)
      candidate_errors.empty?
    end
    errors << "#{location}: must match exactly one oneOf branch" unless matches == 1
  end

  if schema.key?("type")
    types = Array(schema["type"])
    unless types.any? { |type| type_valid?(value, type) }
      errors << "#{location}: expected #{types.join(' or ')}"
      return
    end
  end

  if schema.key?("enum") && !schema["enum"].include?(value)
    errors << "#{location}: expected one of #{schema['enum'].join(', ')}"
  end

  if schema.key?("pattern") && value.is_a?(String) && !Regexp.new(schema["pattern"]).match?(value)
    errors << "#{location}: does not match pattern #{schema['pattern']}"
  end

  if schema.key?("minLength") && value.is_a?(String) && value.length < schema["minLength"]
    errors << "#{location}: length must be at least #{schema['minLength']}"
  end

  if schema.key?("minItems") && value.is_a?(Array) && value.length < schema["minItems"]
    errors << "#{location}: must contain at least #{schema['minItems']} item(s)"
  end

  if schema.key?("minimum") && value.is_a?(Numeric) && value < schema["minimum"]
    errors << "#{location}: must be at least #{schema['minimum']}"
  end

  if schema.key?("maximum") && value.is_a?(Numeric) && value > schema["maximum"]
    errors << "#{location}: must be at most #{schema['maximum']}"
  end

  validate_format(value, schema["format"], location, errors) if schema.key?("format")

  if value.is_a?(Hash)
    Array(schema["required"]).each do |field|
      errors << "#{location}.#{field}: missing required field" unless value.key?(field)
    end

    if schema["additionalProperties"] == false
      allowed = schema.fetch("properties", {}).keys
      value.keys.each do |field|
        errors << "#{location}.#{field}: additional property is not allowed" unless allowed.include?(field)
      end
    end

    schema.fetch("properties", {}).each do |field, child_schema|
      validate_schema(child_schema, value[field], "#{location}.#{field}", errors) if value.key?(field)
    end
  end

  return unless value.is_a?(Array) && schema.key?("items")

  value.each_with_index do |item, index|
    validate_schema(schema["items"], item, "#{location}[#{index}]", errors)
  end
end

errors = []

Dir[SCHEMA_ROOT.join("*.schema.json")].sort.each do |path|
  load_json(path)
rescue StandardError => e
  errors << e.message
end

SCHEMA_TARGETS.each do |relative_path, schema_name, data_path|
  vector_path = VECTOR_ROOT.join(relative_path)
  schema_path = SCHEMA_ROOT.join(schema_name)

  begin
    vector = load_json(vector_path)
    schema = load_json(schema_path)
    data = dig_path(vector, data_path)
  rescue StandardError => e
    errors << "#{relative_path}: #{e.message}"
    next
  end

  validate_schema(schema, data, "#{relative_path}:#{data_path.join('.')}", errors)
end

claim_schema = load_json(SCHEMA_ROOT.join("claim-values.schema.json"))
CLAIM_SCHEMA_CASES.each do |relative_path|
  begin
    vector = load_json(VECTOR_ROOT.join(relative_path))
    values = dig_path(vector, %w[input claim_values])
    expected_valid = dig_path(vector, %w[expected valid])
    case_errors = []
    validate_schema(
      claim_schema,
      values,
      "#{relative_path}:input.claim_values",
      case_errors
    )
    actual_valid = case_errors.empty?
    if actual_valid != expected_valid
      errors << "#{relative_path}: expected valid=#{expected_valid}, got " \
                "valid=#{actual_valid} (#{case_errors.join('; ')})"
    end
  rescue StandardError => e
    errors << "#{relative_path}: #{e.message}"
  end
end

if errors.empty?
  puts "Schemas OK"
else
  warn errors.join("\n")
  exit 1
end
