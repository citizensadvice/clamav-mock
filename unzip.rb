#!/usr/bin/ruby
# frozen_string_literal: true

require "stringio"
require "zip"

# Write to a StringIO or you get seek errors
file = StringIO.new($stdin.read, "rb")

# Unzip the password protected sample files. The password is eicar
decrypter = Zip::TraditionalDecrypter.new("eicar")
Zip::InputStream.open(file, decrypter:) do |input|
  input.get_next_entry
  puts input.read
end
