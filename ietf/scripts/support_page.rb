# frozen_string_literal: true

require "cgi"
require "pathname"

module SupportPage
  TEMPLATE = Pathname.new(__dir__).join("..", "templates", "aep-support.html").expand_path
  PATH_MARKER = "__AEP_PAGE_PATH__"

  def self.render(title, introduction, body)
    abort "#{TEMPLATE}: generated support template is required" unless TEMPLATE.file?

    replacements = {
      "__AEP_PAGE_CONTENT__" => body,
      "__AEP_PAGE_DESCRIPTION__" => CGI.escapeHTML(introduction),
      "__AEP_PAGE_HEADING__" => CGI.escapeHTML(title),
      "__AEP_PAGE_TITLE__" => CGI.escapeHTML("#{title} | AEP Foundation")
    }
    rendered = TEMPLATE.read
    replacements.each do |marker, replacement|
      abort "#{TEMPLATE}: missing #{marker}" unless rendered.include?(marker)

      rendered = rendered.gsub(marker) { replacement }
    end
    rendered
  end

  def self.with_path(content, path)
    abort "#{TEMPLATE}: missing #{PATH_MARKER}" unless content.include?(PATH_MARKER)

    rendered = content.gsub(PATH_MARKER) { CGI.escapeHTML(path) }
    abort "#{path}: unreplaced AEP page marker" if rendered.match?(/__AEP_PAGE_[A-Z]+__/)

    rendered
  end
end
