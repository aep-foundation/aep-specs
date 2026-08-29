#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "json_schemer"
require "pathname"
require "time"

module ConformanceHarness
  PROTOCOL_VERSION = "1"
  AEP_VERSION = "1.0"
  ROLES = %w[agent platform service].freeze
  PROFILES = %w[core-http claims api-key basic oauth-bearer platform-hosted-identity].freeze
  STATUSES = %w[passed failed skipped].freeze
  EXPECTATIONS = %w[required optional unsupported].freeze
  VECTOR_FIELDS = %w[id title description drafts category applicability input expected].freeze
  REQUIRED_VECTOR_FIELDS = VECTOR_FIELDS

  module_function

  def load_json(path)
    JSON.parse(path.read)
  rescue JSON::ParserError => error
    raise "#{path}: invalid JSON: #{error.message}"
  end

  def validate_schema!(document, schema_path, label)
    errors = JSONSchemer.schema(load_json(schema_path)).validate(document).to_a
    return if errors.empty?

    details = errors.map { |error| error.fetch("error") }.join("; ")
    raise "#{label} is invalid: #{details}"
  end

  def load_manifest(path, schema_path)
    manifest = load_json(path)
    validate_schema!(manifest, schema_path, "capability manifest")
    roles = manifest.fetch("claims").map { |claim| claim.fetch("role") }
    raise "capability manifest roles must be unique" unless roles == roles.uniq

    manifest
  end

  def load_vectors(root, selected_suites)
    index = load_json(root.join("index.json"))
    validate_index!(index, root)
    vectors = index.fetch("vectors").map do |relative_path|
      [relative_path, load_json(root.join(relative_path))]
    end
    selected = if selected_suites.empty?
                 vectors
               else
                 vectors.select { |_, vector| selected_suites.include?(vector.fetch("category")) }
               end
    unknown = selected_suites - vectors.map { |_, vector| vector.fetch("category") }.uniq
    raise "unknown suites: #{unknown.join(', ')}" unless unknown.empty?

    [index, vectors, selected]
  end

  def validate_index!(index, root)
    expected_fields = %w[index_version vectors]
    raise "vector index fields are invalid" unless index.is_a?(Hash) && index.keys.sort == expected_fields
    raise "index_version must be #{PROTOCOL_VERSION}" unless index["index_version"] == PROTOCOL_VERSION

    paths = index["vectors"]
    raise "vectors must be a non-empty array" unless paths.is_a?(Array) && !paths.empty?
    raise "vector paths must be sorted and unique" unless paths == paths.sort.uniq

    indexed = paths.map { |path| root.join(path).cleanpath }
    prefix = "#{root.cleanpath}/"
    raise "vector path escapes the vector root" unless indexed.all? { |path| path.to_s.start_with?(prefix) }
    raise "indexed vector is missing" unless indexed.all?(&:file?)

    discovered = Dir[root.join("**", "*.json")].filter_map do |path|
      relative = Pathname.new(path).relative_path_from(root).to_s
      relative unless relative == "index.json"
    end.sort
    raise "vector index does not match discovered vectors" unless paths == discovered

    identities = indexed.each_with_index.map do |path, position|
      vector = load_json(path)
      validate_vector!(vector)
      category = Pathname.new(paths.fetch(position)).dirname.to_s
      raise "#{path}: category does not match its index path" unless vector.fetch("category") == category

      [vector.fetch("category"), vector.fetch("id")]
    end
    raise "vector category and identifier pairs must be unique" unless identities == identities.uniq
  end

  def validate_vector!(vector)
    raise "vector fields are invalid" unless vector.is_a?(Hash) && (vector.keys - VECTOR_FIELDS).empty?
    raise "vector metadata is incomplete" unless REQUIRED_VECTOR_FIELDS.all? { |field| vector.key?(field) }
    raise "vector strings are invalid" unless %w[id title description category].all? do |field|
      vector[field].is_a?(String) && !vector[field].empty?
    end
    raise "vector input and expected values must be objects" unless vector["input"].is_a?(Hash) &&
      vector["expected"].is_a?(Hash)
    raise "vector drafts are invalid" unless nonempty_unique_strings?(vector["drafts"])
    validate_applicability!(vector["applicability"])
  end

  def validate_applicability!(applicability)
    raise "vector applicability must classify every role" unless applicability.is_a?(Hash) &&
      applicability.keys == ROLES

    applicability.each do |role, rule|
      raise "vector applicability for #{role} must be an object" unless rule.is_a?(Hash)

      expectation = rule["expectation"]
      raise "vector applicability expectation for #{role} is invalid" unless EXPECTATIONS.include?(expectation)
      expected_fields = expectation == "unsupported" ? %w[expectation] : %w[expectation profile]
      raise "vector applicability fields for #{role} are invalid" unless rule.keys.sort == expected_fields
      next if expectation == "unsupported"

      raise "vector applicability profile for #{role} is invalid" unless PROFILES.include?(rule["profile"])
    end
    raise "vector must be executable by at least one role" if applicability.values.all? do |rule|
      rule.fetch("expectation") == "unsupported"
    end
  end

  def nonempty_unique_strings?(values)
    values.is_a?(Array) && !values.empty? && values == values.uniq &&
      values.all? { |value| value.is_a?(String) && !value.empty? }
  end

  def revision(index, vectors)
    digest = Digest::SHA256.new
    digest << JSON.generate("index_version" => index.fetch("index_version"))
    vectors.each do |path, vector|
      digest << path
      digest << JSON.generate(vector)
    end
    "sha256:#{digest.hexdigest}"
  end

  def manifest_revision(path)
    "sha256:#{Digest::SHA256.file(path).hexdigest}"
  end

  def requests(vectors, role, profiles)
    sequence = 0
    vectors.filter_map do |_, vector|
      applicability = vector.fetch("applicability").fetch(role)
      next if applicability.fetch("expectation") == "unsupported"
      next unless profiles.include?(applicability.fetch("profile"))

      sequence += 1
      {
        "protocol_version" => PROTOCOL_VERSION,
        "sequence" => sequence,
        "role" => role,
        "profile" => applicability.fetch("profile"),
        "expectation" => applicability.fetch("expectation"),
        "vector" => vector.slice("id", "title", "drafts", "category"),
        "case" => vector.slice("input", "expected")
      }
    end
  end

  def validate_response!(response, schema_path, expected_sequences, required_sequences)
    validate_schema!(response, schema_path, "adapter response")
    sequence = response.fetch("sequence")
    raise "adapter response sequence is unexpected: #{sequence}" unless expected_sequences.include?(sequence)
    if response.fetch("status") == "skipped" && required_sequences.include?(sequence)
      raise "adapter skipped required sequence #{sequence}"
    end
  end

  def report(manifest:, role:, profiles:, manifest_revision:, vector_revision:, requests:, responses:)
    suites = requests.group_by { |request| [request.dig("vector", "category"), request.fetch("profile")] }
      .sort_by(&:first)
      .map do |(category, profile), suite_requests|
        statuses = suite_requests.map { |request| responses.fetch(request.fetch("sequence")).fetch("status") }
        {
          "category" => category,
          "profile" => profile,
          "passed" => statuses.count("passed"),
          "failed" => statuses.count("failed"),
          "skipped" => statuses.count("skipped")
        }
      end

    {
      "report_version" => PROTOCOL_VERSION,
      "generated_at" => Time.now.utc.iso8601,
      "implementation" => manifest.fetch("implementation"),
      "role" => role,
      "profiles" => profiles,
      "aep_version" => AEP_VERSION,
      "manifest_revision" => manifest_revision,
      "vector_revision" => vector_revision,
      "suites" => suites
    }
  end
end
