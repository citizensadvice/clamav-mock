# frozen_string_literal: true

require "socket"
require "clamav/client"
require_relative "./backgrounded"
require "debug"

EICAR = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

unless ENV.fetch("START_CLAMD", nil) == "false"
  ENV["CLAMD_TCP_HOST"] = ENV.fetch("CLAMD_TCP_HOST", "localhost")
  ENV["CLAMD_TCP_PORT"] = ENV.fetch("CLAMD_TCP_PORT", nil) || Addrinfo.tcp("", 0).bind { |s| s.local_address.ip_port }.to_s
end

RSpec.describe "APP" do
  extend Backgrounded
  background_app unless ENV["START_CLAMD"] == "false"

  subject(:app) { ClamAV::Client.new }

  let(:default_socket) { ClamAV::Client.new.resolve_default_socket }
  let(:null_connection) { ClamAV::Connection.new(socket: default_socket, wrapper: ClamAV::Wrappers::NullTerminationWrapper.new) }

  describe "PING" do
    it "returns PONG" do
      expect(app.ping).to be true
    end

    context "with alternate line termination" do
      subject(:app) { ClamAV::Client.new(null_connection) }

      it "returns PONG" do
        expect(app.ping).to be true
      end
    end
  end

  describe "a text file" do
    it "returns ok" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end

    context "with alternate line termination" do
      subject(:app) { ClamAV::Client.new(null_connection) }

      it "returns ok" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end
  end

  describe "a binary file" do
    it "returns ok" do
      io = File.open("#{__dir__}/fixtures/war_and_peace.epub", "r")
      response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end

  describe "a text file containing the eicar string" do
    it "returns virus" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR)))
      expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Win.Test.EICAR_HDB-1")
    end

    context "with alternate line termination" do
      subject(:app) { ClamAV::Client.new(null_connection) }

      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR)))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Win.Test.EICAR_HDB-1")
      end
    end

    context "when in middle of string" do
      it "returns ok" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("foo#{EICAR}bar")))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "when at the start of a string" do
      it "returns ok" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("#{EICAR}bar")))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "when at the end of a string" do
      it "returns ok" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("foo#{EICAR}")))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "when padded with white space" do
      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("#{EICAR}  ")))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Eicar-Signature")
      end
    end

    context "when padded with white space to 127 characters" do
      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR.ljust(127, " \t\r\n\x1a"))))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Eicar-Signature")
      end
    end

    context "when padded with white space to beyond 128 characters" do
      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR.ljust(129, " \t\r\n\x1a"))))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "when across chunk boundaries" do
      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR), 10))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Win.Test.EICAR_HDB-1")
      end
    end
  end

  describe "a zip file" do
    context "without a virus" do
      it "returns ok" do
        io = File.open("#{__dir__}/fixtures/ok.zip", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "with an encrypted zip (unreadable)" do
      it "returns ok" do
        io = File.open("#{__dir__}/fixtures/zip-with-encryption.zip", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "with an unsupported zip (unreadable)" do
      it "returns ok" do
        io = File.open("#{__dir__}/fixtures/zip-with-unsupported-compression.zip", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "with large zip (will not be read)" do
      it "returns ok" do
        io = File.open("#{__dir__}/fixtures/large-zip.zip", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "with an invalid zip" do
      it "returns ok" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("\x50\x4B\x03\x04foobar")))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "with a virus" do
      it "returns virus" do
        io = File.open("#{__dir__}/fixtures/eicar_com.zip", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Win.Test.EICAR_HDB-1")
      end
    end

    context "with a zip within a zip with a virus" do
      it "returns virus" do
        io = File.open("#{__dir__}/fixtures/eicarcom2.zip", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Win.Test.EICAR_HDB-1")
      end
    end
  end

  describe "word documents" do
    context "without a virus" do
      it "returns ok" do
        io = File.open("#{__dir__}/fixtures/ok.docx", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to eq ClamAV::SuccessResponse.new("stream")
      end
    end

    context "with the test virus" do
      it "returns virus" do
        io = File.open("#{__dir__}/fixtures/eicar.docx", "r")
        response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
        expect(response).to have_attributes(class: ClamAV::VirusResponse, virus_name: "Win.Test.EICAR_HDB-1")
      end
    end
  end

  describe "multiple submissions" do
    it "returns PONG" do
      expect(app.ping).to be true
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end
end
