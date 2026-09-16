#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

check_only = ARGV.delete("--check")
output = ARGV.shift
abort "usage: render_protocol_support_tree.rb [--check] OUTPUT" unless output && ARGV.empty?

IETF_ROOT = Pathname.new(__dir__).join("..").expand_path
ASSET_PATH = '#{onboardingPath}'
GITHUB_ROOT = "https://github.com/aep-foundation/aep-specs"
LOCAL_PATH = '#{onboardingPath}'

def humanize(value)
  {
    "client-assertion" => "Client Assertions",
    "grant-revoke" => "Grant and Revoke",
    "openapi" => "OpenAPI",
    "protected-resource" => "Protected Resources"
  }.fetch(value, value.tr("-_", "  ").split.map(&:capitalize).join(" "))
end

def item(label, links, children = [])
  arguments = [label, links, ASSET_PATH].map { |value| JSON.generate(value) }
  options = ["nested=true"]
  options.concat(["folder=true", "collapsed=true"]) unless children.empty?
  rendered = "{{- protocolTocItem(#{(arguments + options).join(', ')}) -}}"
  unless children.empty?
    rendered += "\n  {{- openUl(\"protocol-toc-children\") -}}\n"
    rendered += children.map { |child| child.lines.map { |line| "    #{line}" }.join }.join
    rendered += "  {{- closeUl() -}}\n"
  end
  "#{rendered}{{- protocolTocItemEnd() -}}\n"
end

def schema_children(source, publication_path)
  source.children.select { |path| path.file? && path.basename.to_s.end_with?(".schema.json") }.sort.map do |path|
    name = path.basename.to_s
    item(name, [["open", "#{LOCAL_PATH}/#{publication_path}/#{name}", false]])
  end
end

sections = []
sections << item(
  "Protocol Schemas",
  [["browse", "#{LOCAL_PATH}/schemas/", false], ["github", "#{GITHUB_ROOT}/tree/main/ietf/schemas"]],
  schema_children(IETF_ROOT.join("schemas"), "schemas")
)

conformance_labels = {
  "adapter-request.schema.json" => "Adapter Request",
  "adapter-response.schema.json" => "Adapter Response",
  "capability-manifest.schema.json" => "Capability Manifest",
  "report.schema.json" => "Conformance Report",
  "vector-index.schema.json" => "Vector Index"
}
conformance_children = [item("Conformance Model", [["github", "#{GITHUB_ROOT}/blob/main/ietf/conformance/README.md"]])]
conformance_children.concat(IETF_ROOT.join("conformance").children.select do |path|
  path.file? && path.basename.to_s.end_with?(".schema.json")
end.sort.map do |path|
  name = path.basename.to_s
  item(conformance_labels.fetch(name, name), [["open", "#{LOCAL_PATH}/conformance/#{name}", false]])
end)
sections << item(
  "Conformance",
  [["browse", "#{LOCAL_PATH}/conformance/", false], ["github", "#{GITHUB_ROOT}/tree/main/ietf/conformance"]],
  conformance_children
)

test_vector_children = IETF_ROOT.join("test-vectors").children.select do |directory|
  directory.directory? && !directory.glob("**/*.json").empty?
end.sort.map do |directory|
  name = directory.basename.to_s
  item(humanize(name), [["browse", "#{LOCAL_PATH}/test-vectors/#{name}/", false]])
end
sections << item(
  "Test Vectors",
  [["browse", "#{LOCAL_PATH}/test-vectors/", false], ["github", "#{GITHUB_ROOT}/tree/main/ietf/test-vectors"]],
  test_vector_children
)

example_labels = {
  "api-key-grant-revoke" => "API-key Grant and Revoke",
  "authorization-composition" => "Authorization Composition",
  "basic-grant-revoke" => "Basic Grant and Revoke",
  "claims-negotiation" => "Claims Negotiation",
  "enroll-grant-revoke-transcript" => "Enroll, Grant, and Revoke",
  "inspect-document" => "Inspect Document",
  "openapi-authentication" => "OpenAPI Authentication",
  "pending-enroll-status" => "Pending Enroll and Status",
  "protected-resource-authentication" => "Protected Resource Authentication",
  "status-states" => "Status States"
}
example_children = IETF_ROOT.join("examples").children.select do |path|
  path.file? && path.extname == ".md" && path.basename.to_s != "README.md"
end.sort.map do |path|
  title = path.read.lines.find { |line| line.start_with?("# ") }&.delete_prefix("# ")&.strip
  abort "#{path}: top-level title is required" if title.to_s.empty?

  name = path.basename(".md").to_s
  item(example_labels.fetch(name, title), [["open", "#{LOCAL_PATH}/examples/#{name}.html", false]])
end
sections << item(
  "Examples",
  [["browse", "#{LOCAL_PATH}/examples/", false], ["github", "#{GITHUB_ROOT}/tree/main/ietf/examples"]],
  example_children
)

guide_children = [item("Implementer Guide", [["open", "#{LOCAL_PATH}/guides/implementer-guide.html", false]])]
sections << item(
  "Guides",
  [["browse", "#{LOCAL_PATH}/guides/", false], ["github", "#{GITHUB_ROOT}/tree/main/ietf/guides"]],
  guide_children
)

governance_children = [
  item("Project Governance", [["open", "#{LOCAL_PATH}/governance/project-governance.html", false]]),
  item("Extension Registration", [["open", "#{LOCAL_PATH}/governance/extension-registration.html", false]]),
  item("Extension Registry", [["browse", "#{LOCAL_PATH}/registry/", false]])
]
sections << item(
  "Governance",
  [["browse", "#{LOCAL_PATH}/governance/", false], ["github", "#{GITHUB_ROOT}/blob/main/GOVERNANCE.md"]],
  governance_children
)

rendered = sections.join.chomp
target = Pathname.new(output).expand_path
if check_only
  abort "#{target}: missing" unless target.file?
  abort "#{target}: out of date" unless target.read == rendered

  puts "Published protocol support tree OK"
else
  target.dirname.mkpath
  target.write(rendered)
  puts "Protocol support tree published"
end
