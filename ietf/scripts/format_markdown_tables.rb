#!/usr/bin/env ruby
# frozen_string_literal: true

Align = Struct.new(:left, :right)

def table_line?(line)
  stripped = line.strip
  stripped.start_with?("|") && stripped.end_with?("|")
end

def cells(line)
  line.strip.delete_prefix("|").delete_suffix("|").split("|", -1).map(&:strip)
end

def delimiter_line?(line)
  return false unless table_line?(line)

  cells(line).all? { |cell| cell.match?(/\A:?-{3,}:?\z/) }
end

def delimiter_alignments(line)
  cells(line).map { |cell| Align.new(cell.start_with?(":"), cell.end_with?(":")) }
end

def delimiter_for(width, alignment)
  width = [width, 3].max

  case [alignment.left, alignment.right]
  when [true, true]
    ":#{"-" * (width - 2)}:"
  when [true, false]
    ":#{"-" * (width - 1)}"
  when [false, true]
    "#{"-" * (width - 1)}:"
  else
    "-" * width
  end
end

def format_table(lines)
  rows = lines.map { |line| cells(line) }
  alignments = delimiter_alignments(lines[1])
  column_count = rows.map(&:length).max

  rows.each { |row| row.fill("", row.length...column_count) }
  alignments.fill(Align.new(false, false), alignments.length...column_count)

  widths = Array.new(column_count, 3)
  rows.each_with_index do |row, index|
    next if index == 1

    row.each_with_index do |cell, column|
      widths[column] = [widths[column], cell.length].max
    end
  end

  rows.each_with_index.map do |row, index|
    rendered = row.each_with_index.map do |cell, column|
      text = if index == 1
        delimiter_for(widths[column], alignments[column])
      else
        cell.ljust(widths[column])
      end
      " #{text} "
    end

    "|#{rendered.join("|")}|"
  end
end

def format_markdown(text)
  lines = text.lines(chomp: true)
  output = []
  index = 0

  while index < lines.length
    if index + 1 < lines.length && table_line?(lines[index]) && delimiter_line?(lines[index + 1])
      table = []
      while index < lines.length && table_line?(lines[index])
        table << lines[index]
        index += 1
      end
      output.concat(format_table(table))
    else
      output << lines[index]
      index += 1
    end
  end

  "#{output.join("\n")}\n"
end

if ARGV.empty?
  warn "usage: ruby scripts/format_markdown_tables.rb FILE [FILE ...]"
  exit 1
end

ARGV.each do |path|
  original = File.read(path)
  formatted = format_markdown(original)
  File.write(path, formatted) unless formatted == original
end
