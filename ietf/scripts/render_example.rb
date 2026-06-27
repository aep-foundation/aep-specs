# frozen_string_literal: true

require "cgi"
require "kramdown"

source, output = ARGV
abort "usage: render_example.rb SOURCE.md OUTPUT.html" unless source && output

markdown = File.read(source)
title = markdown.lines.find { |line| line.start_with?("# ") }&.sub(/^#\s+/, "")&.strip || "AEP Example"
body = Kramdown::Document.new(markdown, input: "GFM").to_html

html = <<~HTML
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{CGI.escapeHTML(title)} - AEP Foundation</title>
      <style>
        :root {
          color-scheme: light;
          --border: #d7dde5;
          --code: #f4f7fb;
          --fg: #17202a;
          --link: #0f5e9c;
          --muted: #5c6b7a;
        }

        body {
          color: var(--fg);
          font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          line-height: 1.55;
          margin: 0;
        }

        main {
          margin: 0 auto;
          max-width: 960px;
          padding: 40px 20px 64px;
        }

        a {
          color: var(--link);
        }

        h1 {
          font-size: 2rem;
          line-height: 1.2;
          margin: 0 0 20px;
        }

        h2 {
          border-top: 1px solid var(--border);
          font-size: 1.25rem;
          margin-top: 32px;
          padding-top: 24px;
        }

        p {
          max-width: 760px;
        }

        pre {
          background: var(--code);
          border: 1px solid var(--border);
          overflow-x: auto;
          padding: 14px;
        }

        code {
          font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          font-size: 0.92em;
        }

        .back {
          color: var(--muted);
          display: inline-block;
          margin-bottom: 24px;
          text-decoration: none;
        }
      </style>
    </head>
    <body>
      <main>
        <a class="back" href="../">AEP Foundation Specifications</a>
        #{body}
      </main>
    </body>
  </html>
HTML

File.write(output, html)
