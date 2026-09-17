#!/usr/bin/env ruby
# frozen_string_literal: true

# Zvkt is a timing-property extension, so it has no instruction-result test.
# This audit ensures every vector crypto instruction implemented by this model
# retains the spec metadata consumed by timing-aware backends.

require "pathname"

root = Pathname.new(__dir__).parent
instruction_directories = %w[Zvkb Zvbc Zvkg Zvkned Zvknha Zvks]
instruction_files = instruction_directories.flat_map do |directory|
  Dir[root / "spec/std/isa/inst" / directory / "*.yaml"]
end.sort

abort "No vector crypto instruction definitions found" if instruction_files.empty?

missing = instruction_files.reject do |path|
  File.read(path).match?(/^data_independent_timing: true$/)
end

unless missing.empty?
  abort <<~MESSAGE
    Zvkt metadata audit failed. Missing data_independent_timing: true:
    #{missing.join("\n")}
  MESSAGE
end

puts "Zvkt metadata audit passed: #{instruction_files.size} vector crypto instruction definitions declare data-independent timing."
