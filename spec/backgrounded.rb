# frozen_string_literal: true

require "open3"

module Backgrounded
  def background_app
    app = nil

    before(:all) { app = App.new }

    after(:all) { app.shutdown }
  end

  class App
    def initialize
      @port = ENV["CLAMD_TCP_PORT"]
      @host = ENV["CLAMD_TCP_HOST"]
      start
      wait_for_port
    end

    def shutdown
      Process.kill "TERM", @pid
    end

    private

    def start # rubocop:disable Metrics/MethodLength
      @pid = fork do
        pid = nil
        Signal.trap("TERM") do
          Process.kill "TERM", pid if pid
          exit
        end
        _, _, stderr, wait_thr = Open3.popen3({ "CLAMD_TCP_PORT" => @port.to_s, "CLAMD_TCP_HOST" => @host }, "ruby", "app.rb")
        pid = wait_thr.pid
        stderr.each { |l| puts l }
        wait_thr.value
      end
    end

    def wait_for_port
      now = Time.now
      Socket.tcp(@host, @port, nil, nil, connect_timeout: 0.1, resolv_timeout: 0.1)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
      retry if Time.now - now < 5

      raise
    end
  end
end
