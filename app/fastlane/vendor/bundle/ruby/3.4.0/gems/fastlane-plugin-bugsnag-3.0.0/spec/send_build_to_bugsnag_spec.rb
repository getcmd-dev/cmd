require 'spec_helper'
require 'json'
require 'fastlane/actions/get_info_plist_value'
require_relative '../lib/fastlane/plugin/bugsnag/actions/bugsnag_cli'


BuildAction = Fastlane::Actions::SendBuildToBugsnagAction
GIT_REVISION = `git rev-parse HEAD`.strip
BUILDER = `whoami`.strip
GIT_REPO_URL = `git config --get remote.origin.url`.strip

describe BuildAction do
  def run_with args
    BuildAction.run(Fastlane::ConfigurationHelper.parse(BuildAction, args))
  end

  context 'building an iOS project' do
    it 'detects default Info.plist file excluding test dirs' do
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789AAA --version-name 2.0-other --bundle-version 22 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
      Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
        run_with({})
      end
    end

    it 'reads api key from legacy location' do
      # the API key is now in `bugsnag.apiKey`, it used to be in 'BugsnagAPIKey',
      # test this can be extracted correctly from the `ios_proj_legacy`
      expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789BBB --version-name 4.0-project --bundle-version 44 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
      Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj_legacy')) do
        run_with({})
      end
    end

    context 'using default config_file option' do
      context 'override API key from config' do
        it 'reads API key from the api_key option' do
          expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789FFF --version-name 2.0-other --bundle-version 22 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
          Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
            run_with({
              api_key: '12345678901234567890123456789FFF'
            })
          end
        end

        it 'uses input versions from options' do
          expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789AAA --version-name 8.0.0 --bundle-version 800 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
          Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
            run_with({
              app_version: '8.0.0',
              ios_bundle_version: '800'
            })
          end
        end
      end
    end

    context 'override config_file option' do
      it 'reads API key and version info from the config file' do
        expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789DDD --version-name 3.0-project --bundle-version 33 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
        Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
          run_with({
            config_file: File.join('Project', 'Info.plist')
          })
        end
      end

      context 'override API key, and config file' do
        it 'uses the input api_key to override a non default config' do
          expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789EEE --version-name 3.0-project --bundle-version 33 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
          Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
            run_with({
              config_file: File.join('Project', 'Info.plist'),
              api_key: '12345678901234567890123456789EEE'
            })
          end
        end

        it 'uses the input versions to override a non default config' do
          expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789DDD --version-name 9.0.0 --bundle-version 900 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL}").and_return(true)
          Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
            run_with({
              config_file: File.join('Project', 'Info.plist'),
              app_version: '9.0.0',
              ios_bundle_version: '900'
            })
          end
        end
      end
    end

    context 'metadata added to args' do
      it "single key:value pair added" do
        expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789DDD --version-name 4.0-project --bundle-version 22 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL} --metadata \"test1\": \"First test\"").and_return(true)
        Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
          run_with({
            app_version: '4.0-project',
            api_key: '12345678901234567890123456789DDD',
            metadata: '"test1": "First test"'
          })
        end
      end

      it "multiple key:value pairs added" do
        expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789DDD --version-name 4.0-project --bundle-version 22 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL} --metadata \"test1\": \"First test\", \"test2\": \"Second test\", \"test3\": \"Third test\"").and_return(true)
        Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
          run_with({
                     app_version: '4.0-project',
                     api_key: '12345678901234567890123456789DDD',
                     metadata: '"test1": "First test", "test2": "Second test", "test3": "Third test"'
                   })
        end
      end

      it "multiple key:value pairs added as a hash" do
        expect(Kernel).to receive(:system).with("#{BUGSNAG_CLI_PATH} create-build --api-key 12345678901234567890123456789DDD --version-name 4.0-project --bundle-version 22 --builder-name #{BUILDER} --revision #{GIT_REVISION} --repository #{GIT_REPO_URL} --metadata \"custom_field_1\"=\"value1\",\"custom_field_2\"=\"value2\"").and_return(true)
        Dir.chdir(File.join(FIXTURE_PATH, 'ios_proj')) do
          run_with({
                     app_version: '4.0-project',
                     api_key: '12345678901234567890123456789DDD',
                     metadata: {
                       "custom_field_1": "value1",
                       "custom_field_2": "value2"
                     }
                   })
        end
      end
    end
  end
end
