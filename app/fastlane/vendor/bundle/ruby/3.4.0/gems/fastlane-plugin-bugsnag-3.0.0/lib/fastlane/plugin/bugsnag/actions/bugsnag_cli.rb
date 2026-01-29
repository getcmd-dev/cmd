require 'os'
require 'rbconfig'

class BugsnagCli
  def self.get_bugsnag_cli_path(params)
    bundled_bugsnag_cli_path = self.get_bundled_path
    bundled_bugsnag_cli_version = Gem::Version.new(`#{bundled_bugsnag_cli_path} --version`.scan(/(?:\d+\.?){3}/).first)

    if params[:bugsnag_cli_path]
      bugsnag_cli_path = params[:bugsnag_cli_path] || bundled_bugsnag_cli_path

      bugsnag_cli_version = Gem::Version.new(`#{bugsnag_cli_path} --version`.scan(/(?:\d+\.?){3}/).first)

      if bugsnag_cli_version < bundled_bugsnag_cli_version
        FastlaneCore::UI.warning("The installed bugsnag-cli at #{bugsnag_cli_path} is outdated (#{bugsnag_cli_version}). The current bundled version is: #{bundled_bugsnag_cli_version}. It is recommended that you either update your installed version or use the bundled version.")
      end
      FastlaneCore::UI.verbose("Using bugsnag-cli from path: #{bugsnag_cli_path}")
      bugsnag_cli_path
    else
      FastlaneCore::UI.verbose("Using bundled bugsnag-cli from path: #{bundled_bugsnag_cli_path}")
      bundled_bugsnag_cli_path
    end
  end

  def self.get_bundled_path
    host_cpu = RbConfig::CONFIG['host_cpu']
    if OS.mac?
      if host_cpu =~ /arm|aarch64/
        self.bin_folder('arm64-macos-bugsnag-cli')
      else
        self.bin_folder('x86_64-macos-bugsnag-cli')
      end
    elsif OS.windows?
      if OS.bits == 64
        self.bin_folder('x86_64-windows-bugsnag-cli.exe')
      else
        self.bin_folder('i386-windows-bugsnag-cli.exe')
      end
    else
      if host_cpu =~ /arm|aarch64/
        self.bin_folder('arm64-linux-bugsnag-cli')
      elsif OS.bits == 64
        self.bin_folder('x86_64-linux-bugsnag-cli')
      else
        self.bin_folder('i386-linux-bugsnag-cli')
      end
    end
  end

  def self.bin_folder(filename)
    File.expand_path("../../../../../bin/#{filename}", File.dirname(__FILE__))
  end

  def self.create_build_args(api_key, version_name, version_code, bundle_version, release_stage, builder, revision, repository, provider, auto_assign_release, metadata, retries, timeout, endpoint)
    args = []
    args += ["--api-key", api_key] unless api_key.nil?
    args += ["--version-name", version_name] unless version_name.nil?
    args += ["--version-code", version_code] unless version_code.nil?
    args += ["--bundle-version", bundle_version] unless bundle_version.nil?
    args += ["--release-stage", release_stage] unless release_stage.nil?
    args += ["--builder-name", builder] unless builder.nil?
    args += ["--revision", revision] unless revision.nil?
    args += ["--repository", repository] unless repository.nil?
    args += ["--provider", provider] unless provider.nil?
    args += ["--auto-assign-release"] if auto_assign_release
    unless metadata.nil?
      if metadata.is_a?(String)
        #
        args += ["--metadata", metadata]
      elsif metadata.is_a?(Hash)
        formatted_metadata = metadata.map { |k, v| %Q{"#{k}"="#{v}"} }.join(",")
        args += ["--metadata", formatted_metadata]
      end
    end
    args += ["--retries", retries] unless retries.nil?
    args += ["--timeout", timeout] unless timeout.nil?
    args += ["--build-api-root-url", endpoint] unless endpoint.nil?
    args += ["--verbose"] if FastlaneCore::Globals.verbose?
    args
  end

  def self.upload_args dir, upload_url, project_root, api_key, ignore_missing_dwarf, ignore_empty_dsym, dryrun, log_level, port, retries, timeout, configuration, scheme, plist, xcode_project
    args = []
    args += ["--verbose"] if FastlaneCore::Globals.verbose?
    args += ["--ignore-missing-dwarf"] if ignore_missing_dwarf
    args += ["--ignore-empty-dsym"] if ignore_empty_dsym
    args += ["--api-key", api_key] unless api_key.nil?
    args += ["--upload-api-root-url", upload_url] unless upload_url.nil?
    args += ["--project-root", project_root] unless project_root.nil?
    args += ["--dry-run"] if dryrun
    args += ["--log-level", log_level] unless log_level.nil?
    args += ["--port", port] unless port.nil?
    args += ["--retries", retries] unless retries.nil?
    args += ["--timeout", timeout] unless timeout.nil?
    args += ["--configuration", configuration] unless configuration.nil?
    args += ["--scheme", scheme] unless scheme.nil?
    args += ["--plist", plist] unless plist.nil?
    args += ["--xcode-project", xcode_project] unless xcode_project.nil?
    args << dir
    args
  end

  def self.upload_dsym cli_path, args
    bugsnag_cli_command = "#{cli_path} upload dsym #{args.join(' ')}"
    FastlaneCore::UI.verbose("Running command: #{bugsnag_cli_command}")
    Kernel.system(bugsnag_cli_command)
  end

  def self.create_build cli_path, args
    bugsnag_cli_command = "#{cli_path} create-build #{args.join(' ')}"
    FastlaneCore::UI.verbose("Running command: #{bugsnag_cli_command}")
    Kernel.system(bugsnag_cli_command)
  end
end


