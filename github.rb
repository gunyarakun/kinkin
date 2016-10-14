# frozen_string_literal: true
require 'git'
require 'fileutils'

Git.configure do |config|
end

class Github
  def self.commit_id(path)
    g = Git.open(path)
    g.object('HEAD').sha
  end

  def self.clone(repository, path, options = {})
    Git.clone(repository, path, options)
  end

  def self.clone_or_pull(repository, path, options = {})
    g = Git.open(path)
    g.pull
  rescue ArgumentError
    clone(repository, path, options)
  end

  def self.delete_and_clone(repository, path, options = {})
    path = File.expand_path(path)
    script_dir = File.expand_path(File.dirname(__FILE__))

    unless path.start_with?(script_dir)
      raise 'Cannot delete a directory except under this project.'
    end

    FileUtils.rm_rf(path)
    clone(repository, path, options)
  end
end
