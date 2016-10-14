# kinkin

An example of CI scripts which receives Webhook, build and notify the result into Slack.

## Install

`rbenv` is required.

```sh
gem install bundler
bundle install
```

## Config

```sh
cp ci_config.rb.template ci_config.rb
# edit it
```

## Launch

```ruby
rackup -E production -p 31919 -o 0.0.0.0
```

## Set Webhook on Github

Set the URL into Github.

```
http://example.com:31919/github_webhook
```

## See stdout/stderr on log

- http://example.com:31919/stdout_log
- http://example.com:31919/stderr_log
