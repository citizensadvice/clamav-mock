#!/usr/bin/ruby
# frozen_string_literal: true

require "stringio"
require "zip"
require "debug"

file = StringIO.new($stdin.read, "rb")

decrypter = Zip::TraditionalDecrypter.new("eicar")
Zip::InputStream.open(file, decrypter:) do |input|
  input.get_next_entry
  puts input.read
end
