#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"
require "kramdown"
require "pathname"
require_relative "support_page"

check_only = ARGV.delete("--check")
section = ARGV.shift || "all"
sections = %w[all examples governance guides registry test-vectors]
abort "usage: publish_support_artifacts.rb [--check] [#{sections.join('|')}]" unless sections.include?(section) && ARGV.empty?

IETF_ROOT = Pathname.new(__dir__).join("..").expand_path
REPOSITORY_ROOT = IETF_ROOT.join("..").expand_path
DOCS_ROOT = REPOSITORY_ROOT.join("docs")

def h(value)
  CGI.escapeHTML(value.to_s)
end

def page(title, introduction, body)
  SupportPage.render(title, introduction, body.strip)
end

def page_paths(artifacts, section)
  artifacts.to_h do |relative, content|
    next [relative, content] unless relative.end_with?(".html")

    path = relative.end_with?("index.html") ? "/#{section}/#{relative.delete_suffix('index.html')}" : "/#{section}/#{relative}"
    [relative, SupportPage.with_path(content, path)]
  end
end

def table(headers, rows)
  head = headers.map { |header| "<th>#{h(header)}</th>" }.join
  body = rows.map { |row| "<tr>#{row.map { |cell| "<td>#{cell}</td>" }.join}</tr>" }.join("\n")
  "<table><thead><tr>#{head}</tr></thead><tbody>#{body}</tbody></table>"
end

def markdown_html(markdown)
  Kramdown::Document.new(markdown, input: "GFM").to_html
end

def markdown_title(markdown, fallback)
  markdown.lines.find { |line| line.start_with?("# ") }&.delete_prefix("# ")&.strip || fallback
end

def markdown_collection_artifacts(entries, title, introduction)
  rows = []
  artifacts = {}
  entries.each do |source, output_name|
    markdown = source.read
    entry_title = markdown_title(markdown, source.basename(".md").to_s.tr("-", " ").split.map(&:capitalize).join(" "))
    artifacts[output_name] = page(entry_title, "Non-normative AEP implementation guidance.", markdown_html(markdown.sub(/\A# .+\n/, "")))
    rows << ["<a href=\"#{h(output_name)}\">#{h(entry_title)}</a>", h(source.basename.to_s)]
  end
  artifacts["index.html"] = page(title, introduction, table(%w[Document Source], rows))
  artifacts
end

def markdown_collection_index(entries, title, introduction)
  rows = entries.map do |source, output_name|
    markdown = source.read
    entry_title = markdown_title(markdown, source.basename(".md").to_s.tr("-", " ").split.map(&:capitalize).join(" "))
    ["<a href=\"#{h(output_name)}\">#{h(entry_title)}</a>", h(source.basename.to_s)]
  end
  { "index.html" => page(title, introduction, table(%w[Document Source], rows)) }
end

def file_tree_artifacts(source, title, introduction)
  artifacts = {}
  files = source.glob("**/*").select(&:file?).sort
  files.each do |path|
    next if path.basename.to_s == "README.md"

    artifacts[path.relative_path_from(source).to_s] = path.read
  end

  directories = [source] + source.glob("**/*").select do |directory|
    directory.directory? && !directory.glob("**/*").select(&:file?).empty?
  end.sort
  directories.each do |directory|
    relative = directory.relative_path_from(source)
    rows = directory.children.reject { |path| path.basename.to_s == "README.md" }.sort.map do |path|
      name = path.basename.to_s
      href = path.directory? ? "#{name}/" : name
      ["<a href=\"#{h(href)}\"><code>#{h(name)}</code></a>", path.directory? ? "Directory" : "Artifact"]
    end
    page_title = directory == source ? title : directory.basename.to_s.tr("-_", "  ").split.map(&:capitalize).join(" ")
    page_introduction = directory == source ? introduction : "Browsable artifacts from #{title}."
    index = relative.to_s == "." ? "index.html" : relative.join("index.html").to_s
    artifacts[index] = page(page_title, page_introduction, table(%w[Name Type], rows))
  end
  artifacts
end

def synchronize(destination, expected, check_only, preserve_unmanaged: false)
  existing = destination.directory? ? Dir[destination.join("**", "*")].select { |path| File.file?(path) }.map do |path|
    Pathname.new(path).relative_path_from(destination).to_s
  end : []
  errors = []

  expected.each do |relative, content|
    target = destination.join(relative)
    if check_only
      errors << "#{target}: missing" unless target.file?
      errors << "#{target}: out of date" if target.file? && target.read != content
    else
      FileUtils.mkdir_p(target.dirname)
      target.write(content)
    end
  end
  (preserve_unmanaged ? [] : existing - expected.keys).each do |relative|
    target = destination.join(relative)
    check_only ? errors << "#{target}: unexpected file" : target.delete
  end
  errors
end

examples = IETF_ROOT.join("examples").children.select { |path| path.file? && path.extname == ".md" && path.basename.to_s != "README.md" }.sort
guides = IETF_ROOT.join("guides").children.select { |path| path.file? && path.extname == ".md" && path.basename.to_s != "README.md" }.sort
governance = [
  [REPOSITORY_ROOT.join("GOVERNANCE.md"), "project-governance.html"],
  [IETF_ROOT.join("governance", "extension-registration.md"), "extension-registration.html"]
]

generators = {
  "test-vectors" => lambda {
    file_tree_artifacts(IETF_ROOT.join("test-vectors"), "AEP Test Vectors", "Language-neutral positive and negative Agent Enrollment Protocol conformance cases.")
  },
  "registry" => lambda {
    file_tree_artifacts(IETF_ROOT.join("registry"), "AEP Extension Registry", "Repository-local, machine-readable registrations for AEP protocol identifiers.")
  },
  "examples" => lambda {
    entries = examples.map { |path| [path, "#{path.basename('.md')}.html"] }
    markdown_collection_index(entries, "AEP Examples", "Non-normative Agent Enrollment Protocol exchanges and implementation scenarios.")
  },
  "guides" => lambda {
    entries = guides.map { |path| [path, "#{path.basename('.md')}.html"] }
    markdown_collection_artifacts(entries, "AEP Guides", "Non-normative guidance for implementing and maintaining AEP.")
  },
  "governance" => lambda {
    markdown_collection_artifacts(governance, "AEP Governance", "Project governance and extension-registration guidance for AEP.")
  }
}

selected = section == "all" ? generators : generators.slice(section)
errors = selected.flat_map do |name, generator|
  synchronize(DOCS_ROOT.join(name), page_paths(generator.call, name), check_only, preserve_unmanaged: name == "examples")
end

if errors.empty?
  puts check_only ? "Published support artifacts OK" : "Support artifacts published"
else
  warn errors.join("\n")
  exit 1
end
