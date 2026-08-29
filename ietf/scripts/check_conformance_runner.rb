#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "rbconfig"
require "tempfile"

ietf_root = Pathname.new(__dir__).join("..").expand_path
runner = Pathname.new(__dir__).join("run_conformance.rb").expand_path
adapter = ietf_root.join("conformance", "fixture-adapter.rb")
manifest = ietf_root.join("conformance", "examples", "capability-manifest.json")
errors = []

def run_harness(runner, adapter, manifest, output, role, mode, suites = [])
  arguments = [
    "bundle",
    "exec",
    RbConfig.ruby,
    runner.to_s,
    "--manifest", manifest.to_s,
    "--role", role,
    "--output", output.path
  ]
  suites.each { |suite| arguments.concat(["--suite", suite]) }
  arguments.concat(["--", RbConfig.ruby, adapter.to_s, mode])
  Open3.capture3(*arguments)
end

Tempfile.create(["aep-conformance-report", ".json"]) do |output|
  _, stderr, status = run_harness(runner, adapter, manifest, output, "agent", "reverse")
  errors << "out-of-order passing adapter failed: #{stderr}" unless status.success?
  if status.success?
    report = JSON.parse(output.read)
    errors << "report role mismatch" unless report["role"] == "agent"
    errors << "report version mismatch" unless report["aep_version"] == "1.0"
    errors << "manifest revision is not content-addressed" unless report["manifest_revision"].match?(/\Asha256:[0-9a-f]{64}\z/)
    errors << "vector revision is not content-addressed" unless report["vector_revision"].match?(/\Asha256:[0-9a-f]{64}\z/)
    errors << "Agent suites were not aggregated" unless report["suites"].length > 1
  end
end

Tempfile.create(["aep-service-conformance-report", ".json"]) do |output|
  _, stderr, status = run_harness(runner, adapter, manifest, output, "service", "passed")
  errors << "Service adapter failed: #{stderr}" unless status.success?
  if status.success?
    report = JSON.parse(output.read)
    errors << "report Service role mismatch" unless report["role"] == "service"
  end
end

Tempfile.create(["aep-platform-conformance-report", ".json"]) do |output|
  _, stderr, status = run_harness(runner, adapter, manifest, output, "platform", "passed")
  errors << "Platform adapter failed: #{stderr}" unless status.success?
  if status.success?
    report = JSON.parse(output.read)
    errors << "Platform profiles mismatch" unless report["profiles"] == ["platform-hosted-identity"]
  end
end

Tempfile.create(["aep-conformance-report", ".json"]) do |output|
  _, stderr, status = run_harness(runner, adapter, manifest, output, "agent", "failed", ["inspect"])
  errors << "failing adapter did not return exit status 1" unless status.exitstatus == 1
  if status.exitstatus == 1
    report = JSON.parse(output.read)
    failed = report.fetch("suites").sum { |suite| suite.fetch("failed") }
    errors << "failed results were not recorded" unless failed.positive?
    errors << "failed vector diagnostics are missing" if stderr.empty?
  end
end

{
  "invalid" => "invalid response did not fail the harness",
  "skipped" => "required skip did not fail the harness",
  "duplicate" => "duplicate response did not fail the harness",
  "malformed" => "malformed response did not fail the harness",
  "missing" => "missing response did not fail the harness",
  "nonzero" => "nonzero adapter exit did not fail the harness"
}.each do |mode, message|
  Tempfile.create(["aep-conformance-report", ".json"]) do |output|
    _, _, status = run_harness(runner, adapter, manifest, output, "agent", mode, ["inspect"])
    errors << message unless status.exitstatus == 1
  end
end

if errors.empty?
  puts "Conformance runner OK"
else
  warn errors.join("\n")
  exit 1
end
