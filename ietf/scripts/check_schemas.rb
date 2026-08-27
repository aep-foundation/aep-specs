#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "ipaddr"
require "json_schemer"

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
  ["inspect/default-endpoint-base.json", "inspect-document.schema.json", %w[expected document]],
  ["inspect/forward-compatible-advertisements.json", "inspect-document.schema.json", %w[input document]],
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

INVALID_SCHEMA_TARGETS = [
  ["inspect/authenticated-command-without-identity-method.json", "inspect-document.schema.json", %w[input document]],
  ["inspect/authentication-method-limit.json", "inspect-document.schema.json", %w[input document]],
  ["inspect/command-without-inspect.json", "inspect-document.schema.json", %w[input document]],
  ["inspect/grant-without-grant-types.json", "inspect-document.schema.json", %w[input document]],
  ["inspect/invalid-advertisement-identifiers.json", "inspect-document.schema.json", %w[input document]],
  ["inspect/invalid-openapi-reference.json", "inspect-document.schema.json", %w[input document]],
  ["inspect/missing-signing-algorithm.json", "inspect-document.schema.json", %w[input document]],
  [
    "platform/verification-authenticate-missing-resource.json",
    "platform-verification-request.schema.json",
    %w[input request]
  ]
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

def schema_errors(schema, value)
  JSONSchemer.schema(
    schema,
    formats: {
      "email" => proc { |instance, _format| instance.is_a?(String) && valid_mailbox?(instance) }
    }
  ).validate(value).map { |error| error.fetch("error") }.to_a
end

errors = []

Dir[SCHEMA_ROOT.join("*.schema.json")].sort.each do |path|
  schema = load_json(path)
  JSONSchemer.validate_schema(schema).each do |error|
    errors << "#{path}: #{error.fetch('error')}"
  end
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

  schema_errors(schema, data).each do |error|
    errors << "#{relative_path}:#{data_path.join('.')}: #{error}"
  end
end

INVALID_SCHEMA_TARGETS.each do |relative_path, schema_name, data_path|
  vector_path = VECTOR_ROOT.join(relative_path)
  schema_path = SCHEMA_ROOT.join(schema_name)

  begin
    vector = load_json(vector_path)
    schema = load_json(schema_path)
    data = dig_path(vector, data_path)
    errors << "#{relative_path}: expected schema rejection" if schema_errors(schema, data).empty?
  rescue StandardError => e
    errors << "#{relative_path}: #{e.message}"
  end
end

claim_schema = load_json(SCHEMA_ROOT.join("claim-values.schema.json"))
CLAIM_SCHEMA_CASES.each do |relative_path|
  begin
    vector = load_json(VECTOR_ROOT.join(relative_path))
    values = dig_path(vector, %w[input claim_values])
    expected_valid = dig_path(vector, %w[expected valid])
    case_errors = schema_errors(claim_schema, values)
    actual_valid = case_errors.empty?
    if actual_valid != expected_valid
      errors << "#{relative_path}: expected valid=#{expected_valid}, got " \
                "valid=#{actual_valid} (#{case_errors.join('; ')})"
    end
  rescue StandardError => e
    errors << "#{relative_path}: #{e.message}"
  end
end

inspect_schema = load_json(SCHEMA_ROOT.join("inspect-document.schema.json"))
minimal_inspect = load_json(VECTOR_ROOT.join("inspect/minimal-http.json")).fetch("expected")
version_vector = load_json(VECTOR_ROOT.join("inspect/protocol-version.json"))
version_vector.dig("expected", "cases").each do |test_case|
  document = minimal_inspect.merge("aep_version" => test_case.fetch("received"))
  actual_valid = schema_errors(inspect_schema, document).empty?
  expected_valid = test_case.fetch("valid")
  next if actual_valid == expected_valid

  errors << "inspect/protocol-version.json:#{test_case.fetch('name')}: expected valid=#{expected_valid}, got valid=#{actual_valid}"
end

platform_schema = load_json(SCHEMA_ROOT.join("platform-discovery.schema.json"))
platform_discovery = load_json(VECTOR_ROOT.join("platform/discovery.json")).fetch("expected")
%w[1.0 1.7].each do |version|
  errors << "platform/discovery.json: aep_version #{version} must be valid" unless schema_errors(
    platform_schema,
    platform_discovery.merge("aep_version" => version)
  ).empty?
end
errors << "platform/discovery.json: aep_version 01.0 must be invalid" if schema_errors(
  platform_schema,
  platform_discovery.merge("aep_version" => "01.0")
).empty?

if errors.empty?
  puts "Schemas OK"
else
  warn errors.join("\n")
  exit 1
end
