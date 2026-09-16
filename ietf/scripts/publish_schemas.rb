#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "pathname"
require_relative "support_page"

check_only = ARGV.delete("--check")
source = Pathname.new(ARGV[0] || "")
destination = Pathname.new(ARGV[1] || "")

abort "usage: publish_schemas.rb [--check] SOURCE_DIR DESTINATION_DIR" if source.to_s.empty? || destination.to_s.empty?
abort "#{source}: source directory does not exist" unless source.directory?

schema_paths = source.children.select { |path| path.file? && path.basename.to_s.end_with?(".schema.json") }.sort
abort "#{source}: no schema files found" if schema_paths.empty?

def h(value)
  CGI.escapeHTML(value.to_s)
end

def schema_title(path)
  JSON.parse(path.read).fetch("title")
rescue JSON::ParserError => e
  abort "#{path}: invalid JSON: #{e.message}"
end

def render_index(schema_paths, source)
  rows = schema_paths.map do |path|
    name = path.basename.to_s
    title = schema_title(path)

    <<~HTML
      <tr>
        <td><a href="#{h(name)}"><code>#{h(name)}</code></a></td>
        <td>#{h(title)}</td>
      </tr>
    HTML
  end.join

  title, introduction = if source.basename.to_s == "conformance"
    ["AEP Conformance Schemas", "JSON Schemas for the offline AEP conformance harness. These documents are not AEP wire objects."]
  else
    ["AEP JSON Schemas", "JSON Schemas for stable Agent Enrollment Protocol wire objects. The Internet-Draft prose remains authoritative."]
  end
  table = "<table><thead><tr><th>Schema</th><th>Title</th></tr></thead><tbody>#{rows}</tbody></table>"
  SupportPage.with_path(SupportPage.render(title, introduction, table), "/#{source.basename}/")
end

expected = schema_paths.to_h do |path|
  [path.basename.to_s, path.read]
end
expected["index.html"] = render_index(schema_paths, source)

if check_only
  errors = []
  expected.each do |name, content|
    target = destination.join(name)
    if !target.file?
      errors << "#{target}: missing"
    elsif target.read != content
      errors << "#{target}: out of date"
    end
  end

  if destination.directory?
    destination.children.select(&:file?).each do |path|
      errors << "#{path}: unexpected file" unless expected.key?(path.basename.to_s)
    end
  end

  if errors.empty?
    label = source.basename.to_s == "conformance" ? "Published conformance schemas" : "Published schemas"
    puts "#{label} OK"
  else
    warn errors.join("\n")
    exit 1
  end
else
  FileUtils.mkdir_p(destination)
  expected.each do |name, content|
    destination.join(name).write(content)
  end
end
