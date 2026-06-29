#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
REGISTRY_ROOT = ROOT.join("registry")
SCHEMA_PATH = REGISTRY_ROOT.join("registry-entry.schema.json")
ENTRY_PATHS = Dir[REGISTRY_ROOT.join("{grant-types,identity-methods}/*.json")].sort.map { |path| Pathname.new(path) }

def load_json(path)
  JSON.parse(path.read)
rescue JSON::ParserError => e
  raise "#{path}: invalid JSON: #{e.message}"
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

def validate_schema(schema, value, location, errors)
  if schema.key?("type")
    types = Array(schema["type"])
    unless types.any? { |type| type_valid?(value, type) }
      errors << "#{location}: expected #{types.join(' or ')}"
      return
    end
  end

  errors << "#{location}: expected one of #{schema['enum'].join(', ')}" if schema.key?("enum") && !schema["enum"].include?(value)
  errors << "#{location}: does not match pattern #{schema['pattern']}" if schema.key?("pattern") && value.is_a?(String) && !Regexp.new(schema["pattern"]).match?(value)
  errors << "#{location}: length must be at least #{schema['minLength']}" if schema.key?("minLength") && value.is_a?(String) && value.length < schema["minLength"]

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
schema = load_json(SCHEMA_PATH)

if ENTRY_PATHS.empty?
  errors << "#{REGISTRY_ROOT.join('grant-types')}: no grant type entries found"
end

seen_ids = {}
seen_wire_identifiers = {}

ENTRY_PATHS.each do |path|
  entry = load_json(path)
  rel = path.relative_path_from(ROOT).to_s

  validate_schema(schema, entry, rel, errors)

  id = entry["id"]
  wire_identifier = entry["wire_identifier"]
  version = entry["version"]

  errors << "#{rel}: id is duplicated by #{seen_ids[id]}" if id && seen_ids.key?(id)
  errors << "#{rel}: wire_identifier is duplicated by #{seen_wire_identifiers[wire_identifier]}" if wire_identifier && seen_wire_identifiers.key?(wire_identifier)
  seen_ids[id] = rel if id
  seen_wire_identifiers[wire_identifier] = rel if wire_identifier

  expected_filename = "#{wire_identifier.tr(':', '-')}.json" if wire_identifier
  errors << "#{rel}: filename must match wire_identifier" if expected_filename && path.basename.to_s != expected_filename
  errors << "#{rel}: id version must match version" if id && version && !id.end_with?("#v=#{version}")

  if entry["kind"] == "grant_type"
    errors << "#{rel}: inspect.grant_type must match wire_identifier" unless entry.dig("inspect", "grant_type") == wire_identifier
    errors << "#{rel}: inspect.config_key must match wire_identifier" unless entry.dig("inspect", "config_key") == wire_identifier
  end

  spec_path = entry.dig("specification", "path")
  errors << "#{rel}: specification.path does not exist: #{spec_path}" if spec_path && !ROOT.parent.join(spec_path).file?

  entry.fetch("artifacts", {}).each do |artifact_type, paths|
    Array(paths).each do |artifact_path|
      errors << "#{rel}: #{artifact_type} path does not exist: #{artifact_path}" unless ROOT.parent.join(artifact_path).file?
    end
  end
end

if errors.empty?
  puts "Registry OK"
else
  warn errors.join("\n")
  exit 1
end
