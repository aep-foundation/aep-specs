#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

mode = ARGV.fetch(0, "passed")
requests = $stdin.each_line.map { |line| JSON.parse(line) }
requests.reverse! if mode == "reverse"

if mode == "malformed"
  puts "{"
  exit
end

responses = requests.map do |request|
  status = case mode
           when "failed" then "failed"
           when "skipped" then "skipped"
           when "invalid" then "invalid"
           when "skip-optional"
             request.fetch("expectation") == "optional" ? "skipped" : "passed"
           else "passed"
           end
  {
    "protocol_version" => "1",
    "sequence" => request.fetch("sequence"),
    "status" => status
  }
end
responses << responses.first if mode == "duplicate"
responses.pop if mode == "missing"
responses.each { |response| puts JSON.generate(response) }
exit 7 if mode == "nonzero"
