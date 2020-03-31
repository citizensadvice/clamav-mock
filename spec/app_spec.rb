# frozen_string_literal: true

require "socket"
require "clamav/client"

eicar = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

RSpec.describe "APP" do
  subject { ClamAV::Client.new }

  describe "PING" do
    it "returns PONG" do
      expect(subject.ping).to eq true
    end
  end

  describe "a text file" do
    it "returns ok" do
      response = subject.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end

  describe "a binary file" do
    it "returns ok" do
      io = File.open("#{__dir__}/war_and_peace.epub", "r")
      response = subject.execute(ClamAV::Commands::InstreamCommand.new(io))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end

  describe "eicar" do
    it "returns virus" do
      response = subject.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new(eicar)))
      expect(response).to be_kind_of ClamAV::VirusResponse
    end
  end

  describe "in middle of string" do
    it "returns virus" do
      response = subject.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("foo" + eicar + "bar")))
      expect(response).to be_kind_of ClamAV::VirusResponse
    end
  end

  describe "across chunk boundaries" do
    it "returns virus" do
      response = subject.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("foo" + eicar + "bar"), 10))
      expect(response).to be_kind_of ClamAV::VirusResponse
    end
  end

  describe "multiple submissions" do
    it "returns PONG" do
      expect(subject.ping).to eq true
      response = subject.execute(ClamAV::Commands::InstreamCommand.new(StringIO.new("some data")))
      expect(response).to eq ClamAV::SuccessResponse.new("stream")
    end
  end
end
