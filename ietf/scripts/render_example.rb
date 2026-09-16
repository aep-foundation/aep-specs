# frozen_string_literal: true

require "kramdown"
require_relative "support_page"

source, output = ARGV
abort "usage: render_example.rb SOURCE.md OUTPUT.html" unless source && output

markdown = File.read(source)
title = markdown.lines.find { |line| line.start_with?("# ") }&.sub(/^#\s+/, "")&.strip || "AEP Example"
body = '<a class="back" href="/examples/">All examples</a>' + Kramdown::Document.new(markdown.sub(/\A# .+\n/, ""), input: "GFM").to_html

html = SupportPage.with_path(SupportPage.render(title, "Non-normative AEP example.", body), "/examples/#{File.basename(output)}")

File.write(output, html)
