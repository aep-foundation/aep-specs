#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "pathname"
require_relative "conformance_harness"

options = { suites: [] }
parser = OptionParser.new do |arguments|
  arguments.banner = "Usage: run_conformance.rb [options] -- ADAPTER [ARGUMENT ...]"
  arguments.on("--manifest PATH") { |path| options[:manifest] = path }
  arguments.on("--role ROLE", ConformanceHarness::ROLES) { |role| options[:role] = role }
  arguments.on("--suite CATEGORY") { |suite| options[:suites] << suite }
  arguments.on("--output PATH") { |path| options[:output] = path }
end
parser.order!
ARGV.shift if ARGV.first == "--"

required = %i[manifest role output]
missing = required.reject { |key| options[key].is_a?(String) && !options[key].empty? }
abort parser.to_s unless missing.empty? && !ARGV.empty?

ietf_root = Pathname.new(__dir__).join("..").expand_path
conformance_root = ietf_root.join("conformance")
manifest_path = Pathname.new(options.fetch(:manifest)).expand_path
manifest = ConformanceHarness.load_manifest(
  manifest_path,
  conformance_root.join("capability-manifest.schema.json")
)
claim = manifest.fetch("claims").find { |candidate| candidate.fetch("role") == options.fetch(:role) }
abort "capability manifest does not claim the #{options.fetch(:role)} role" unless claim

index, all_vectors, selected_vectors = ConformanceHarness.load_vectors(
  ietf_root.join("test-vectors"),
  options.fetch(:suites)
)
profiles = claim.fetch("profiles")
requests = ConformanceHarness.requests(selected_vectors, options.fetch(:role), profiles)
abort "no cases selected" if requests.empty?

request_schema = conformance_root.join("adapter-request.schema.json")
requests.each { |request| ConformanceHarness.validate_schema!(request, request_schema, "adapter request") }
expected_sequences = requests.map { |request| request.fetch("sequence") }
required_sequences = requests.filter_map do |request|
  request.fetch("sequence") if request.fetch("expectation") == "required"
end
responses = {}
adapter_errors = []
status = nil

Open3.popen3(*ARGV) do |stdin, stdout, stderr, wait_thread|
  error_reader = Thread.new { stderr.read }
  writer = Thread.new do
    requests.each { |request| stdin.puts(JSON.generate(request)) }
    stdin.close
  rescue Errno::EPIPE => error
    adapter_errors << error.message
  end

  stdout.each_line do |line|
    response = JSON.parse(line)
    ConformanceHarness.validate_response!(
      response,
      conformance_root.join("adapter-response.schema.json"),
      expected_sequences,
      required_sequences
    )
    sequence = response.fetch("sequence")
    raise "adapter returned sequence #{sequence} more than once" if responses.key?(sequence)

    responses[sequence] = response
  end
  writer.join
  status = wait_thread.value
  adapter_stderr = error_reader.value
  warn adapter_stderr unless adapter_stderr.empty?
rescue JSON::ParserError => error
  abort "adapter returned invalid JSON: #{error.message}"
rescue RuntimeError => error
  abort error.message
end

abort adapter_errors.join("\n") unless adapter_errors.empty?
abort "adapter exited with status #{status.exitstatus}" unless status.success?

missing_sequences = expected_sequences - responses.keys
abort "adapter omitted sequences: #{missing_sequences.join(', ')}" unless missing_sequences.empty?

report = ConformanceHarness.report(
  manifest: manifest,
  role: options.fetch(:role),
  profiles: profiles,
  manifest_revision: ConformanceHarness.manifest_revision(manifest_path),
  vector_revision: ConformanceHarness.revision(index, all_vectors),
  requests: requests,
  responses: responses
)
ConformanceHarness.validate_schema!(report, conformance_root.join("report.schema.json"), "conformance report")
Pathname.new(options.fetch(:output)).write("#{JSON.pretty_generate(report)}\n")

requests.each do |request|
  response = responses.fetch(request.fetch("sequence"))
  next unless response.fetch("status") == "failed"

  warn "#{request.dig('vector', 'id')}: #{response.fetch('message', 'failed')}"
end

failed = report.fetch("suites").sum { |suite| suite.fetch("failed") }
exit(failed.zero? ? 0 : 1)
