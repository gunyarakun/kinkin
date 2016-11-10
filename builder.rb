# frozen_string_literal: true
require './github'
require './command'
require './slack'

raise 'Put your ci_config.rb' unless File.exist?('./ci_config.rb')

unless File.stat('./ci_config.rb').mode.to_s(8).end_with?('600')
  raise 'Chmod your ci_config.rb 600'
end

require './ci_config'

class Builder
  WORK_DIR = 'work'

  def initialize(server_name, user_name, project_name, branch, base_path)
    @server_name = server_name
    @user_name = user_name
    @project_name = project_name
    @branch = branch
    @base_path = File.expand_path(File.join(WORK_DIR, base_path))
    @last_build_success = true
  end

  def git_url
    "git@#{@server_name}:#{@user_name}/#{@project_name}.git"
  end

  def https_url
    "https://#{@server_name}/#{@user_name}/#{@project_name}"
  end

  def fetch
    Github.clone_or_pull(git_url, @base_path)
  end

  def delete_and_fetch
    Github.delete_and_clone(git_url, @base_path)
  end

  def build(command, options = {})
    log_open(options, :stdout)
    log_open(options, :stderr)

    Command.execute(command, @base_path, options)
    notify_slack(true)
    true
  rescue CommandExecuteException
    notify_slack(false)
    false
  end

  def log_open(options, type)
    option_symbol = "#{type}_log_io".intern
    return if options.key?(option_symbol)

    log_path = CIConfig.dig(:logger, :build, type, :path)
    return unless log_path

    log_dir = File.dirname(log_path)
    FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)
    options[option_symbol] = File.open(log_path, 'w')
  end

  def notify_slack(build_success) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    slack_config = CIConfig[:slack]
    return if slack_config.nil?

    commit_id = Github.commit_id(@base_path)
    url_base = https_url
    project_url = "#{url_base}/tree/#{@branch}"
    commit_url = "#{url_base}/commit/#{commit_id}"

    if build_success
      return if @last_build_success # Do nothing
      main_text = 'OK now'
      color = 'good'
    elsif @last_build_success
      main_text = 'FAIL'
      color = 'danger'
    else
      main_text = 'Still FAIL'
      color = 'danger'
    end
    pretext = "<#{project_url}|[#{@project_name}:#{@branch}]> CI result"
    text = "<#{commit_url}|`#{commit_id[0..7]}`> #{main_text}"
    if slack_config[:stdout_log_url]
      text += " (<#{slack_config[:stdout_log_url]}|stdout_log>)"
    end
    if slack_config[:stderr_log_url]
      text += " (<#{slack_config[:stderr_log_url]}|stderr_log>)"
    end

    s = Slack.new(slack_config)
    s.post_message(slack_config[:channel], slack_config[:name], slack_config[:icon_url], [{
                     mrkdwn_in: %w(text pretext),
                     color: color,
                     fallback: text,
                     pretext: pretext,
                     text: text,
                     ts: Time.now.to_i
                   }])

    @last_build_success = build_success

    text
  end
end
