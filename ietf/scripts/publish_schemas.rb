#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "pathname"

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

def render_index(schema_paths)
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

  <<~HTML
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>AEP JSON Schemas</title>
        <style>
          :root {
            color-scheme: light dark;
            --bg: #f8fafc;
            --fg: #172033;
            --muted: #5b6475;
            --panel: #ffffff;
            --border: #d7dce5;
            --link: #0b5cad;
          }

          @media (prefers-color-scheme: dark) {
            :root {
              --bg: #10141c;
              --fg: #eef2f8;
              --muted: #aeb7c8;
              --panel: #171d28;
              --border: #2d3545;
              --link: #8ab8ff;
            }
          }

          body {
            margin: 0;
            background: var(--bg);
            color: var(--fg);
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            line-height: 1.5;
          }

          main {
            width: min(920px, calc(100% - 32px));
            margin: 0 auto;
            padding: 48px 0;
          }

          h1 {
            margin: 0 0 8px;
            font-size: clamp(2rem, 6vw, 3.2rem);
            line-height: 1.05;
          }

          p {
            max-width: 760px;
            color: var(--muted);
          }

          a {
            color: var(--link);
          }

          table {
            width: 100%;
            border-collapse: collapse;
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 8px;
            overflow: hidden;
          }

          th,
          td {
            padding: 12px;
            border-bottom: 1px solid var(--border);
            text-align: left;
            vertical-align: top;
          }

          tbody tr:last-child td {
            border-bottom: none;
          }

          th {
            font-size: 0.9rem;
            color: var(--muted);
          }

          code {
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>AEP JSON Schemas</h1>
          <p>
            JSON Schemas for stable Agent Enrollment Protocol wire objects.
            The Internet-Draft prose remains authoritative.
          </p>
          <table>
            <thead>
              <tr>
                <th>Schema</th>
                <th>Title</th>
              </tr>
            </thead>
            <tbody>
    #{rows}
            </tbody>
          </table>
        </main>
      </body>
    </html>
  HTML
end

expected = schema_paths.to_h do |path|
  [path.basename.to_s, path.read]
end
expected["index.html"] = render_index(schema_paths)

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
    puts "Published schemas OK"
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
