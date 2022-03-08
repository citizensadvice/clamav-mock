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

  describe "PING" do
    it "returns PONG" do
      expect(app.ping).to eq true
    end
  end

  describe "a text file" do
    it "returns ok" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end

  describe "a binary file" do
    it "returns ok" do
      io = File.open("#{__dir__}/war_and_peace.epub", "r")
      response = app.execute(ClamAV::Commands::InstreamCommand.new(io))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end

  describe "eicar" do
    it "returns virus" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(EICAR)))
      expect(response).to be_kind_of ClamAV::VirusResponse
    end
  end

  describe "in middle of string" do
    it "returns virus" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("foo#{EICAR}bar")))
      expect(response).to be_kind_of ClamAV::VirusResponse
    end
  end

  describe "across chunk boundaries" do
    it "returns virus" do
      response = app.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("foo#{EICAR}bar"), 10))
      expect(response).to be_kind_of ClamAV::VirusResponse
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
