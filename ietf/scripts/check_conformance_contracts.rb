#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "json_schemer"
require "pathname"

ROOT = Pathname.new(__dir__).join("..", "conformance").expand_path
EXAMPLE_ROOT = ROOT.join("examples")

EXAMPLES = {
  "capability-manifest.json" => "capability-manifest.schema.json",
  "adapter-request.json" => "adapter-request.schema.json",
  "adapter-response.json" => "adapter-response.schema.json",
  "vector-index.json" => "vector-index.schema.json",
  "report.json" => "report.schema.json"
}.freeze

def load_json(path)
  JSON.parse(path.read)
rescue JSON::ParserError => e
  raise "#{path}: invalid JSON: #{e.message}"
end

errors = []
schemas = {}

Dir[ROOT.join("*.schema.json")].sort.each do |path|
  schema_path = Pathname.new(path)
  schema = load_json(schema_path)
  schemas[schema_path.basename.to_s] = schema
  JSONSchemer.validate_schema(schema).each do |error|
    errors << "#{schema_path}: #{error.fetch('error')}"
  end
rescue StandardError => e
  errors << e.message
end

expected_schema_names = EXAMPLES.values.sort
errors << "conformance schema set does not match the validated examples" unless schemas.keys.sort == expected_schema_names

expected_example_names = EXAMPLES.keys.sort
example_names = Dir[EXAMPLE_ROOT.join("*.json")].map { |path| Pathname.new(path).basename.to_s }.sort
errors << "conformance example set is not fully classified" unless example_names == expected_example_names

EXAMPLES.each do |example_name, schema_name|
  begin
    example_path = EXAMPLE_ROOT.join(example_name)
    example = load_json(example_path)
    schema = schemas.fetch(schema_name)
    JSONSchemer.schema(schema).validate(example).each do |error|
      errors << "#{example_path}: #{error.fetch('error')}"
    end
  rescue StandardError => e
    errors << e.message
  end
end

begin
  manifest = load_json(EXAMPLE_ROOT.join("capability-manifest.json"))
  roles = manifest.fetch("claims").map { |claim| claim.fetch("role") }
  errors << "capability manifest roles must be unique" unless roles == roles.uniq
rescue StandardError => e
  errors << e.message
end

begin
  index = load_json(EXAMPLE_ROOT.join("vector-index.json"))
  paths = index.fetch("vectors")
  errors << "vector index paths must be sorted" unless paths == paths.sort
rescue StandardError => e
  errors << e.message
end

if errors.empty?
  puts "Conformance contracts OK"
else
  warn errors.join("\n")
  exit 1
end
