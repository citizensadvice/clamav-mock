#!/usr/bin/ruby
# frozen_string_literal: true

require "clamav/client"

client = ClamAV::Client.new

response = client.execute(ClamAV::Commands::InstreamCommand.new(STDIN))

if response == ClamAV::SuccessResponse.new("stream")
  puts "OK"
else
  puts "VIRUS: #{response.virus_name}"
  exit 1
end
