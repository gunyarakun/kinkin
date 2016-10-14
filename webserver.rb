# frozen_string_literal: true
# rubocop:disable Style/GlobalVars
require 'sinatra'
require 'json'
require 'fileutils'
require 'logger'
require './builder'

$thread = nil

def logger_factory
  logger_config = CIConfig.dig(:logger, :webserver) || {}
  if logger_config.key?(:path) && logger_config[:path]
    log_dir = File.dirname(logger_config[:path])
    FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)
    Logger.new(logger_config[:path], logger_config[:shift_age] || 'daily')
  else
    Logger.new(STDERR)
  end
end

class WebServer < Sinatra::Base
  # Synchronize on a mutex lock
  set :lock, true
  set :logger, logger_factory

  configure do
    mime_type :text_plain, 'text/plain'
  end

  post '/github_webhook' do
    begin
      request.body.rewind
      payload = JSON.parse(request.body.read)

      # NOTE: "set :lock, true" is required.
      Thread.kill($thread) unless $thread.nil?

      $thread = Thread.new do
        bc = CIConfig[:builder]
        b = Builder.new(bc[:server], bc[:user], bc[:project], bc[:branch], bc[:project])
        # fetch
        b.delete_and_fetch
        # and build!!!!!
        b.build('~/.rbenv/versions/2.3.1/bin/gem install bundler && ~/.rbenv/versions/2.3.1/bin/rake')
      end

      settings.logger.info("Webhook: #{JSON.generate(payload)}")

      'ci!'
    rescue StandardError => e
      error_msg = "Error: #{e}"
      settings.logger.error(error_msg)

      error_msg
    end
  end

  get '/stdout_log' do
    log_path = CIConfig.dig(:logger, :build, :stdout, :path)
    return '' unless File.exist?(log_path)
    mime_type :text_plain
    send_file(log_path)
  end

  get '/stderr_log' do
    log_path = CIConfig.dig(:logger, :build, :stderr, :path)
    return '' unless File.exist?(log_path)
    mime_type :text_plain
    send_file(log_path)
  end
end
