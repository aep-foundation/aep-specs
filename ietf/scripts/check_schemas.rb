#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "time"

ROOT = Pathname.new(__dir__).join("..").expand_path
SCHEMA_ROOT = ROOT.join("schemas")
VECTOR_ROOT = ROOT.join("test-vectors")

SCHEMA_TARGETS = [
  ["client-assertion/enroll-claims.json", "client-assertion-claims.schema.json", %w[expected]],
  ["inspect/minimal-http.json", "inspect-document.schema.json", %w[expected]],
  ["enroll/request-minimal.json", "enroll-request.schema.json", %w[input]],
  ["enroll/response-active.json", "enroll-response.schema.json", %w[expected body]],
  ["status/response-active.json", "status-response.schema.json", %w[expected body]],
  ["grant-revoke/grant-request-oauth-bearer.json", "grant-request.schema.json", %w[expected body]],
  ["grant-revoke/revoke-request-oauth-bearer.json", "revoke-request.schema.json", %w[expected body]],
  ["grant-revoke/revoke-request-all-grant-types.json", "revoke-request.schema.json", %w[expected body]],
  ["grant-revoke/revoke-response-empty.json", "revoke-response.schema.json", %w[expected body]],
  ["errors/not-recognized-problem.json", "problem.schema.json", %w[expected body]],
  ["idempotency/enroll-conflict.json", "idempotency-metadata.schema.json", %w[input]],
  ["idempotency/enroll-conflict.json", "problem.schema.json", %w[expected body]],
  ["credentials/oauth-bearer/grant-response.json", "oauth-bearer-grant-response.schema.json", %w[expected]],
  ["credentials/api-key/grant-response.json", "api-key-grant-response.schema.json", %w[expected]],
  ["credentials/basic/grant-response.json", "basic-grant-response.schema.json", %w[expected]]
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

def validate_format(value, format, location, errors)
  return unless format == "date-time"
  return unless value.is_a?(String)

  Time.iso8601(value)
rescue ArgumentError
  errors << "#{location}: must be RFC 3339 date-time"
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

if errors.empty?
  puts "Schemas OK"
else
  warn errors.join("\n")
  exit 1
end
