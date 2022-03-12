#!/usr/bin/ruby
# frozen_string_literal: true

require "socket"
require "stringio"
require "zip"

port = ENV["CLAMD_TCP_PORT"].to_i
port = 3310 if port.zero?

EICAR = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
# optionally padded to with whitespace to 127 characters https://www.eicar.org/?page_id=3950
EICAR_REGEXP = /\A#{Regexp.escape(EICAR)}[ \t\n\r\x1a]{0,60}\z/
EICAR_NAME = "Win.Test.EICAR_HDB-1"
EICAR_LEGACY_NAME = "Eicar-Signature"
ZIP_MAGIC = "\x50\x4B\x03\x04".b
OLE_MAGIC = "\xD0\xCF\x11\xE0".b
MAX_SIZE = 1024 * 100 # 100kb

class ScanIO < StringIO
  def self.new(...)
    instance = super
    instance.binmode
    instance
  end

  def write(data, *)
    # Skip writing if we have enough data
    return data.length if max_size?

    super
  end

  def virus?
    !!virus_name
  end

  def virus_name
    return @virus_name unless @virus_name.nil?

    @virus_name =
      if zip?                           then zip_eicar
      elsif ole?                        then ole_eicar
      elsif string == EICAR             then EICAR_NAME
      elsif EICAR_REGEXP.match?(string) then EICAR_LEGACY_NAME
      else
        false
      end
  end

  private

  def max_size?
    # Allow one extra byte for oversized eicar
    return false if string.length <= 128
    return string.length > MAX_SIZE if zip? || ole?

    string.length > 128
  end

  def zip?
    string[0..3] == ZIP_MAGIC
  end

  def ole?
    string[0..3] == OLE_MAGIC
  end

  def ole_eicar
    # This is to support a particular docx eicar file
    # The eicar is is in an OLENativeStream within the OLE container
    # While you can use ruby-ole to parse the OLE container
    # I can't figure out the OLENativeStream
    # So, we'll just call it the virus if the string is anywhere in the OLE container
    string.include?(EICAR) ? EICAR_NAME : false
  end

  def zip_eicar
    # This doesn't work for some zips, but it is fine for the example eicar files
    stream = Zip::InputStream.new(self)
    while (entry = stream.get_next_entry)
      next if entry.size > MAX_SIZE

      result = check_zip_stream(entry)
      return result unless result == false
    end
    false
  rescue Zip::Error
    false
  end

  def check_zip_stream(entry)
    stream = self.class.new
    stream.write entry.get_input_stream.read
    stream.virus_name
  end
end

current_id = 0

server = TCPServer.new port

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
        io = ScanIO.new
        # Chunks are size, followed by the bytes
        loop do
          size = client.read(4).unpack1("N")
          break if size.zero?

          io.write client.read(size)
        end
        client.write(io.virus? ? "#{session}stream: #{io.virus_name} FOUND#{delimiter}" : "#{session}stream: OK#{delimiter}")
      end

      break unless session
    end
  rescue StandardError => e
    warn e.full_message
  ensure
    client.close
  end
end
