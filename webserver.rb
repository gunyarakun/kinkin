# frozen_string_literal: true
# rubocop:disable Style/GlobalVars
require 'sinatra'
require 'json'
require 'fileutils'
require 'logger'
require './builder'

$queue = Queue.new
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

def enqueue_build
  $queue << true
  settings.logger.info("Queue pushed: #{$queue.length}")
end

class WebServer < Sinatra::Base
  set :logger, logger_factory

  configure do
    mime_type :text_plain, 'text/plain'
    set(:builder) do
      bc = CIConfig[:builder]
      Builder.new(bc[:server], bc[:user], bc[:project], bc[:branch], bc[:project])
    end

    $thread = Thread.new do
      timeout_seconds = CIConfig.dig(:webserver, :build_timeout_seconds) || 3600

      builder = settings.builder
      logger = settings.logger

      loop do
        $queue.pop
        logger.info("Queue poped: #{$queue.length}")
        begin
          Timeout.timeout(timeout_seconds) do
            # fetch
            builder.delete_and_fetch
            # and build!!!!!
            if builder.build('~/.rbenv/versions/2.3.1/bin/gem install bundler && ~/.rbenv/versions/2.3.1/bin/rake')
              logger.info('build successful')
            else
              logger.info('build error')
            end
          end
        rescue Timeout::Error
          logger.error('build timeout')
        end
      end
    end
  end

  post '/github_webhook' do
    begin
      request.body.rewind
      payload = JSON.parse(request.body.read)

      enqueue_build

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
