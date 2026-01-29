require 'spec_helper'
require_relative '../lib/fastlane/plugin/bugsnag/actions/bugsnag_cli'

Action = Fastlane::Actions::UploadSymbolsToBugsnagAction

describe Action do
  def run_with args
    Action.run(Fastlane::ConfigurationHelper.parse(Action, args))
  end

  context "the packaged gem" do
    gem_name = "fastlane-plugin-bugsnag-#{Fastlane::Bugsnag::VERSION}"

    after do
      FileUtils.rm_rf(gem_name)
      FileUtils.rm_rf("#{gem_name}.gem")
    end

    it 'has bundled CLI binaries' do
      system('rake build')
      system("gem unpack #{gem_name}.gem")
      expect(File.exist?(File.join("#{gem_name}", "bin", "arm64-linux-bugsnag-cli"))).to be true
      expect(File.exist?(File.join("#{gem_name}", "bin", "arm64-macos-bugsnag-cli"))).to be true
      expect(File.exist?(File.join("#{gem_name}", "bin", "i386-linux-bugsnag-cli"))).to be true
      expect(File.exist?(File.join("#{gem_name}", "bin", "i386-windows-bugsnag-cli.exe"))).to be true
      expect(File.exist?(File.join("#{gem_name}", "bin", "x86_64-linux-bugsnag-cli"))).to be true
      expect(File.exist?(File.join("#{gem_name}", "bin", "x86_64-macos-bugsnag-cli"))).to be true
      expect(File.exist?(File.join("#{gem_name}", "bin", "x86_64-windows-bugsnag-cli.exe"))).to be true
    end
  end

  describe '#run' do
    it 'UI.user_error when script fails' do
      expect(Fastlane::UI).to receive(:user_error!).with("Failed uploading #{File.join(FIXTURE_PATH, "ios_proj/Project")}")
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{File.join(FIXTURE_PATH, "ios_proj/Project")}\"").and_return(false)
      run_with({dsym_path: File.join(FIXTURE_PATH, "ios_proj/Project")})
    end

    it 'requires the dSYM file path to exist' do
      expect(Fastlane::UI).to receive(:user_error!).at_least(:once)
      run_with({dsym_path: 'fake/file/path'})
    end

    it 'rejects dSYM files which are not a .zip or a directory' do
      expect(Fastlane::UI).to receive(:user_error!).at_least(:once)
      run_with({dsym_path: File.join(FIXTURE_PATH, 'invalid_file')})
    end

    it 'uploads a single .dSYM file' do
      directory = File.join(FIXTURE_PATH, 'dSYMs')
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{directory}\"").and_return(true)
      run_with({dsym_path: File.join(FIXTURE_PATH, 'dSYMs/app.dSYM')})
    end

    it 'uploads a .zip of .dSYM files' do
      path = File.join(FIXTURE_PATH, 'files.zip')
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{path}\"").and_return(true)
      run_with({dsym_path: path})
    end

    it 'uploads multiple .zip files' do
      zip1 = File.join(FIXTURE_PATH, 'files.zip')
      zip2 = File.join(FIXTURE_PATH, 'more_files.zip')
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{zip1}\"").and_return(true)
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{zip2}\"").and_return(true)
      run_with({dsym_path: [zip1, zip2]})
    end

    it 'uploads multiple .dSYM files multiple directories' do
      dsym1 = File.join(FIXTURE_PATH, 'dSYMs/app.dSYM')
      dsym2 = File.join(FIXTURE_PATH, 'stuff/app.dSYM')
      dsym3 = File.join(FIXTURE_PATH, 'dSYMs/app2.dSYM')
      dsym4 = File.join(FIXTURE_PATH, 'stuff/app2.dSYM')
      directories = [File.join(FIXTURE_PATH, 'dSYMs'), File.join(FIXTURE_PATH, 'stuff')]
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{directories[0]}\"").and_return(true)
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{directories[1]}\"").and_return(true)
      run_with({dsym_path: [dsym1, dsym2, dsym3, dsym4]})
    end

    it 'uploads multiple .dSYM files in a single directory' do
      dsym1 = File.join(FIXTURE_PATH, 'dSYMs/app.dSYM')
      dsym2 = File.join(FIXTURE_PATH, 'dSYMs/app2.dSYM')
      directory = File.join(FIXTURE_PATH, 'dSYMs')
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{Dir::pwd} \"#{directory}\"").and_return(true)
      run_with({dsym_path: [dsym1, dsym2]})
    end

    it 'accepts a project root argument' do
      root_path = "/test/test/test"
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --project-root #{root_path} \"#{FIXTURE_PATH}\"").and_return(true)
      run_with({dsym_path: FIXTURE_PATH, project_root: root_path})
    end

    it 'accepts an API key argument' do
      api_key = "123456789123456789001234567890FF"
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --api-key #{api_key} --project-root #{Dir::pwd} \"#{FIXTURE_PATH}\"").and_return(true)
      run_with({dsym_path: FIXTURE_PATH, api_key: api_key})
    end

    it 'accepts an API key argument with no project root' do
      api_key = "123456789012345678901234567890FF"
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --api-key #{api_key} --project-root #{Dir::pwd} \"#{FIXTURE_PATH}\"").and_return(true)
      run_with({dsym_path: FIXTURE_PATH, api_key: api_key, project_root: nil})
    end

    it 'uses default API key argument from plist' do
      root_path = "/test/test/test"
      api_key = "12345678901234567890123456789AAA" # Uses the API Key from ./spec/fixtures/ios_proj/FirstRealFolder/Info.plist
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --api-key #{api_key} --project-root #{root_path} --plist ./FirstRealFolder/Info.plist \"#{FIXTURE_PATH}\"").and_return(true)
      Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
        run_with({dsym_path: FIXTURE_PATH, project_root: root_path})
      end
    end

    it 'uses legacy API key argument from plist' do
      root_path = "/test/test/test"
      api_key = "12345678901234567890123456789BBB" # Uses the API Key from ./spec/fixtures/ios_proj_legacy/Project/Info.plist
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --api-key #{api_key} --project-root #{root_path} --plist ./Project/Info.plist \"#{FIXTURE_PATH}\"").and_return(true)
      Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj_legacy')) do
        run_with({dsym_path: FIXTURE_PATH, project_root: root_path})
      end
    end

    it 'allows option input to overwrite the config file api key' do
      # The order of precedence is 1. option input, 2. env variable, 3. default or config file input (for api key only)
      # The API key in ./spec/fixtures/ios_proj_legacy/Project/Info.plist is 12345678912345678900123456789AAA.
      api_key = "12345678912345678900123456789CCC"
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --api-key #{api_key} --project-root #{File.join(FIXTURE_PATH, 'ios_proj')} --plist Project/Info.plist \"#{FIXTURE_PATH}\"").and_return(true)
      Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
        run_with({dsym_path: FIXTURE_PATH, api_key: api_key, config_file: File.join('Project', 'Info.plist')})
      end
    end

    it 'reject an invalid API key' do
      api_key = "this-is-not-a-hex-key"
      expect(Fastlane::UI).to receive(:user_error!).with("API key should be a 32 character hexadecimal string")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed uploading #{FIXTURE_PATH}")
      Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
        run_with({dsym_path: FIXTURE_PATH, api_key: api_key, config_file: File.join('Project', 'Info.plist')})
      end
    end

    context 'using a private server' do
      it 'uploads to the private server' do
        expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} upload dsym --upload-api-root-url http://myserver.example.com --project-root #{Dir::pwd} \"#{FIXTURE_PATH}\"").and_return(true)
        run_with({dsym_path: FIXTURE_PATH, upload_url: "http://myserver.example.com"})
      end
    end

    it 'accepts a custom bugsnag_cli_path as an option' do
      custom_cli_path = File.join(ENV['HOME'], ".local/bugsnag/bin/bugsnag-cli")
      expect(Kernel).to receive(:system).with("#{custom_cli_path} upload dsym --project-root #{Dir::pwd} \"#{FIXTURE_PATH}\"").and_return(true)
      run_with({dsym_path: FIXTURE_PATH, bugsnag_cli_path: custom_cli_path})
    end

    it 'accepts a custom bugsnag_cli_path with an API key' do
      custom_cli_path = File.join(ENV['HOME'], ".local/bugsnag/bin/bugsnag-cli")
      api_key = "123456789012345678901234567890FF"
      expect(Kernel).to receive(:system).with("#{custom_cli_path} upload dsym --api-key #{api_key} --project-root #{Dir::pwd} \"#{FIXTURE_PATH}\"").and_return(true)
      run_with({dsym_path: FIXTURE_PATH, api_key: api_key, bugsnag_cli_path: custom_cli_path})
    end

    it 'logs a warning when using an outdated CLI version' do
      cli_path = File.join(FIXTURE_PATH, 'dummy_bugsnag_cli.sh')
      bundled_bugsnag_cli_version = `#{BUGSNAG_CLI_PATH} --version`.strip
      allow(Fastlane::Actions::UploadSymbolsToBugsnagAction).to receive(:version_from_cli).and_return("1.0.0")
      allow(Fastlane::Actions::UploadSymbolsToBugsnagAction).to receive(:bundled_bugsnag_cli_version).and_return(bundled_bugsnag_cli_version)

      expect(Fastlane::UI).to receive(:warning).with("The installed bugsnag-cli at #{cli_path} is outdated (1.0.0). The current bundled version is: #{bundled_bugsnag_cli_version}. It is recommended that you either update your installed version or use the bundled version.")
      expect(Kernel).to receive(:system).with("#{cli_path} upload dsym --project-root #{Dir::pwd} \"#{FIXTURE_PATH}\"").and_return(true)

      run_with({dsym_path: FIXTURE_PATH, bugsnag_cli_path: cli_path})
    end

    it 'logs doesnt log a  warning when using an newer CLI version' do
      cli_version = "9.9.9"
      cli_path = File.join(FIXTURE_PATH, 'dummy_bugsnag_cli.sh')
      bundled_bugsnag_cli_version = `#{BUGSNAG_CLI_PATH} --version`.strip
      allow(Fastlane::Actions::UploadSymbolsToBugsnagAction).to receive(:version_from_cli).and_return(cli_version)
      allow(Fastlane::Actions::UploadSymbolsToBugsnagAction).to receive(:bundled_bugsnag_cli_version).and_return(bundled_bugsnag_cli_version)

      expect(Fastlane::UI).not_to receive(:warning)

      ENV['BUGSNAG_CLI_VERSION'] = cli_version
      run_with({dsym_path: FIXTURE_PATH, bugsnag_cli_path: cli_path})
    end
  end
end
