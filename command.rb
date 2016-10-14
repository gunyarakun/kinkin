# frozen_string_literal: true
require 'open3'

class CommandExecuteException < StandardError
  attr_reader :exit_status

  def initialize(message, exit_status)
    @exit_status = exit_status
    super(message)
  end
end

class Command
  POPEN3_READ_BLOCK_SIZE = 1024

  def self.execute(cmd, work_dir, options = {})
    env = options[:env] || {}
    env['USER'] = ENV['USER']
    env['HOME'] = ENV['HOME']

    cmds = ['env', '-i']
    env.each do |k, v|
      cmds << "#{k}=#{v}"
    end
    cmds.concat(['bash', '--login', '-c', "cd \"#{work_dir}\" && #{cmd}"])

    exec_with_popen3(cmds, options[:stdout_log_io] || $stdout, options[:stderr_log_io] || $stderr)
  end

  def self.exec_with_popen3(commands, stdout_target, stderr_target) # rubocop:disable Metrics/MethodLength
    Open3.popen3(*commands) do |stdin, stdout, stderr, wait_thr|
      stdin.close_write

      outputs = [stdout, stderr]
      while outputs.length.positive?
        ios = IO.select(outputs)
        next unless ios
        io = ios[0]
        io.each do |f|
          begin
            block = f.read_nonblock(POPEN3_READ_BLOCK_SIZE)

            output = stdout == f ? stdout_target : stderr_target
            output.write(block)
            output.flush
          rescue EOFError
            outputs.delete(f)
          end
        end
      end

      exit_status = wait_thr.value.exitstatus

      if exit_status.nonzero?
        error_msg = "Error: #{commands}"
        raise CommandExecuteException.new(error_msg, exit_status)
      end

      exit_status
    end
  end
end
