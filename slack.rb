# frozen_string_literal: true
require 'net/http'
require 'json'

class Slack
  def initialize(options)
    @token = options[:token]
  end

  def request(request, post_data = {})
    post_data['token'] = @token
    url = URI("https://slack.com/api/#{request}")
    response = Net::HTTP.post_form(url, post_data)
    response_obj = JSON.parse(response.body)
    raise "Request failed: #{url}" unless response_obj['ok']
    response_obj
  end

  def channels
    d = {}
    request('channels.list')['channels'].each do |channel|
      d[channel['name']] = channel
    end
    d
  end

  def post_message(channel_name, user_name, icon_url = nil, attachments = [])
    post_data = {
      channel: channels[channel_name]['id'],
      username: user_name,
      attachments: attachments.to_json
    }
    post_data[:icon_url] = icon_url if icon_url
    request('chat.postMessage', post_data)
  end
end
