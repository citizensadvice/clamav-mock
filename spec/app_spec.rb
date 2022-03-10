# frozen_string_literal: true

require "socket"
require "clamav/client"
require_relative "./backgrounded"

EICAR = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

unless ENV["START_CLAMD"] == "false"
  ENV["CLAMD_TCP_HOST"] = ENV.fetch("CLAMD_TCP_HOST", "localhost")
  ENV["CLAMD_TCP_PORT"] = ENV["CLAMD_TCP_PORT"] || Addrinfo.tcp("", 0).bind { |s| s.local_address.ip_port }.to_s
end

RSpec.describe "APP" do
  extend Backgrounded
  background_app unless ENV["START_CLAMD"] == "false"

  subject(:app) { ClamAV::Client.new }

  let(:default_socket) { ClamAV::Client.new.resolve_default_socket }
  let(:null_connection) { ClamAV::Connection.new(socket: default_socket, wrapper: ClamAV::Wrappers::NullTerminationWrapper.new) }

  describe "PING" do
    it "returns PONG" do
      expect(app.ping).to eq true
    end

    context "with alternate line termination" do
      subject(:app) { ClamAV::Client.new(null_connection) }

      it "returns PONG" do
        expect(app.ping).to eq true
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

  describe "eicar" do
    it "returns virus" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR)))
      expect(response).to be_kind_of ClamAV::VirusResponse
    end

    context "with alternate line termination" do
      subject(:app) { ClamAV::Client.new(null_connection) }

      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR)))
        expect(response).to be_kind_of ClamAV::VirusResponse
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

    context "when across chunk boundaries" do
      it "returns virus" do
        response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR), 10))
        expect(response).to be_kind_of ClamAV::VirusResponse
      end
    end
  end

  describe "multiple submissions" do
    it "returns PONG" do
      expect(app.ping).to eq true
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end
end
