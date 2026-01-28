require 'os'

module Fastlane
  module Helper
    class SentryHelper
      def self.find_and_check_sentry_cli_path!(params)
        bundled_sentry_cli_path = self.bundled_sentry_cli_path
        bundled_sentry_cli_version = Gem::Version.new(`#{bundled_sentry_cli_path} --version`.scan(/(?:\d+\.?){3}/).first)

        sentry_cli_path = params[:sentry_cli_path] || bundled_sentry_cli_path

        sentry_cli_version = Gem::Version.new(`#{sentry_cli_path} --version`.scan(/(?:\d+\.?){3}/).first)

        if sentry_cli_version < bundled_sentry_cli_version
          UI.user_error!("Your sentry-cli is outdated, please upgrade to at least version #{bundled_sentry_cli_version} and start your lane again!")
        end

        UI.success("Using sentry-cli #{sentry_cli_version}")
        sentry_cli_path
      end

      def self.call_sentry_cli(params, sub_command)
        sentry_path = self.find_and_check_sentry_cli_path!(params)
        command = [sentry_path] + sub_command
        UI.message "Starting sentry-cli..."
        require 'open3'

        final_command = command.map { |arg| Shellwords.escape(arg) }.join(" ")

        if FastlaneCore::Globals.verbose?
          UI.command(final_command)
        end

        Open3.popen3(final_command) do |stdin, stdout, stderr, status_thread|
          out_reader = Thread.new do
            output = []

            stdout.each_line do |line|
              l = line.strip!
              UI.message(l)
              output << l
            end

            output.join
          end

          err_reader = Thread.new do
            stderr.each_line do |line|
              UI.message(line.strip!)
            end
          end

          unless status_thread.value.success?
            UI.user_error!('Error while calling Sentry CLI')
          end

          err_reader.join
          out_reader.value
        end
      end

      def self.bundled_sentry_cli_path
        if OS.mac?
          self.bin_folder('sentry-cli-Darwin-universal')
        elsif OS.windows?
          if OS.bits == 64
            self.bin_folder('sentry-cli-Windows-x86_64.exe')
          else
            self.bin_folder('sentry-cli-Windows-i686.exe')
          end
        else
          if OS.bits == 64
            self.bin_folder('sentry-cli-Linux-x86_64')
          else
            self.bin_folder('sentry-cli-Linux-i686')
          end
        end
      end

      # Get path for files in bin folder. Paths are resolved relative to this file, for which there are also unit tests.
      def self.bin_folder(filename)
        File.expand_path("../../../../../bin/#{filename}", File.dirname(__FILE__))
      end
    end
  end
end
