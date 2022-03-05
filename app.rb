#!/usr/bin/ruby
# frozen_string_literal: true

require "socket"

port = ENV["CLAMD_TCP_PORT"].to_i
port = 3310 if port.zero?

server = TCPServer.new port

eicar = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

current_id = 0

loop do
  Thread.start(server.accept) do |client|
    # https://linux.die.net/man/8/clamd
    session = ""
    loop do
      # Commands start with z or n, which specifies the delimiter for both input and output
      prefix = client.getc
      break if prefix.nil?

      delimiter = case prefix
                  when "z" then "\0"
                  when "n" then "\n"
                  else
                    raise "unexpected message prefix #{prefix}"
                  end

      command = ""
      while (char = client.getc) != delimiter
        command += char
      end

      case command
      when "IDSESSION"
        # Start a session. Assign a number
        session = "#{current_id + 1}: "
        current_id += 1
      when "END"
        # End a session
        break
      when "PING"
        client.write("#{session}PONG#{delimiter}")
      when "INSTREAM"
        buff = ""
        found = false
        # Chunks are size, followed by the bytes + delimiter
        loop do
          size = client.read(4).unpack1("N")
          break if size.zero?

          buff += client.read(size)
          found = true if buff.include?(eicar)
          buff = buff[-eicar.length - 1..] || buff
        end
        client.write(found ? "#{session}stream: Eicar-Test-Signature FOUND#{delimiter}" : "#{session}stream: OK#{delimiter}")
      end

      break unless session
    end
  rescue StandardError => e
    warn e.full_message
  ensure
    client.close
  end
end
