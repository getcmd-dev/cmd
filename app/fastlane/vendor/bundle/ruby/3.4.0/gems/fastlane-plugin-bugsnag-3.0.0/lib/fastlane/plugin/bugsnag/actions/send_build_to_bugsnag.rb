require "xmlsimple"
require "json"
require_relative "find_info_plist_path"
require_relative "bugsnag_cli"

module Fastlane
  module Actions
    class SendBuildToBugsnagAction < Action
      def self.run(params)
        bugsnag_cli_path = BugsnagCli.get_bugsnag_cli_path(params)

        # If a configuration file was found or was specified, load in the options:
        config_options = {}
        if params[:config_file]
          UI.message("Loading build information from #{params[:config_file]}")
          config_options = load_config_file_options(params[:config_file])
        end

        api_key = params[:api_key] || config_options[:apiKey] unless (params[:api_key].nil? && config_options[:apiKey].nil?)
        version_name = params[:app_version] || config_options[:appVersion] unless (params[:app_version].nil? && config_options[:appVersion].nil?)
        version_code = params[:android_version_code] || config_options[:appVersionCode] unless (params[:android_version_code].nil? && config_options[:appVersionCode].nil?)
        bundle_version = params[:ios_bundle_version] || config_options[:appBundleVersion] unless (params[:ios_bundle_version].nil? && config_options[:appBundleVersion].nil?)
        release_stage = params[:release_stage] || config_options[:releaseStage] || "production" unless (params[:release_stage].nil? && config_options[:releaseStage].nil?)
        builder = params[:builder] unless params[:builder].nil?
        revision = params[:revision] unless params[:revision].nil?
        repository = params[:repository] unless params[:repository].nil?
        provider = params[:provider] unless params[:provider].nil?
        auto_assign_release = params[:auto_assign_release] unless params[:auto_assign_release].nil?
        metadata = params[:metadata] unless params[:metadata].nil?
        retries = params[:retries] unless params[:retries].nil?
        timeout = params[:timeout] unless params[:timeout].nil?
        endpoint = params[:endpoint] unless params[:endpoint].nil?


        if api_key.nil? || !api_key.is_a?(String)
          UI.user_error! missing_api_key_message(params)
        end
        if version_name.nil?
          UI.user_error! missing_app_version_message(params)
        end

        args = BugsnagCli.create_build_args(
          api_key,
          version_name,
          version_code,
          bundle_version,
          release_stage,
          builder,
          revision,
          repository,
          provider,
          auto_assign_release,
          metadata,
          retries,
          timeout,
          endpoint
        )
        success = BugsnagCli.create_build bugsnag_cli_path, args
        if success
          UI.success("Build successfully sent to Bugsnag")
        else
          UI.user_error!("Failed to send build to Bugsnag.")
        end
      end

      def self.missing_api_key_message(params)
        message = "A Bugsnag API key is required to release a build. "
        if lane_context[:PLATFORM_NAME] == :android
          if params[:config_file]
            message << "Set com.bugsnag.android.API_KEY in your AndroidManifest.xml to detect API key automatically."
          else
            message << "Set the config_file option with the path to your AndroidManifest.xml and set com.bugsnag.android.API_KEY in it to detect API key automatically."
          end
        else
          if params[:config_file]
            message << "Set bugsnag.apiKey in your Info.plist file to detect API key automatically."
          else
            message << "Set the config_file option with the path to your Info.plist and set bugsnag.apiKey in it to detect API key automatically."
          end
        end
        message
      end

      def self.missing_app_version_message(params)
        message = "An app version must be specified release a build. "
        if lane_context[:PLATFORM_NAME] == :android
          if params[:config_file]
            message << "Set com.bugsnag.android.APP_VERSION in your AndroidManifest.xml to detect this value automatically."
          else
            message << "Set the config_file option with the path to your AndroidManifest.xml and set com.bugsnag.android.APP_VERSION in it to detect this value automatically."
          end
        else
          if params[:config_file]
            message << "Set the app_version option with your app version or set config_file to update the path to your Info.plist"
          else
            message << "Set the config_file option with the path to your Info.plist"
          end
        end
        message
      end

      def self.description
        "Notifies Bugsnag of a build"
      end

      def self.authors
        ["cawllec"]
      end

      def self.example_code
        ['send_build_to_bugsnag']
      end

      def self.category
        :building
      end

      def self.return_value
        nil
      end

      def self.details
        "Notifies Bugsnag of a new build being released including app version and source control details"
      end

      def self.is_supported?(platform)
        [:ios, :mac, :android].include?(platform)
      end

      def self.available_options
        git_options = load_git_remote_options
        [
          FastlaneCore::ConfigItem.new(key: :config_file,
                                       description: "AndroidManifest.xml/Info.plist location",
                                       optional: true,
                                       default_value: default_config_file_path),
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       description: "Bugsnag API Key",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :app_version,
                                       description: "App version being built",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :android_version_code,
                                       description: "Android app version code",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :ios_bundle_version,
                                       description: "iOS/macOS/tvOS bundle version",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :release_stage,
                                       description: "Release stage being built, i.e. staging, production",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :auto_assign_release,
                                       description: "Whether to automatically associate this build with any new error events and sessions that are received for",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :builder,
                                       description: "The name of the entity triggering the build",
                                       optional: true,
                                       default_value: `whoami`.chomp),
          FastlaneCore::ConfigItem.new(key: :repository,
                                       description: "The source control repository URL for this application",
                                       optional: true,
                                       default_value: git_options[:repository]),
          FastlaneCore::ConfigItem.new(key: :revision,
                                       description: "The source control revision id",
                                       optional: true,
                                       default_value: git_options[:revision]),
          FastlaneCore::ConfigItem.new(key: :provider,
                                       description: "The source control provider, one of 'github-enterprise', 'gitlab-onpremise', or 'bitbucket-server', if any",
                                       optional: true,
                                       default_value: nil,
                                       verify_block: proc do |value|
                                         valid = ['github', 'github-enterprise', 'gitlab', 'gitlab-onpremise', 'bitbucket', 'bitbucket-server'].include? value
                                         unless valid
                                           UI.user_error!("Provider must be one of 'github', 'github-enterprise', 'gitlab', 'gitlab-onpremise', 'bitbucket', 'bitbucket-server', or unspecified")
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :endpoint,
                                       description: "Bugsnag deployment endpoint",
                                       default_value: nil,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :metadata,
                                       description: "Metadata",
                                       optional:true,
                                       type: Object,
                                       default_value: nil),
          FastlaneCore::ConfigItem.new(key: :retries,
                                       description: "The number of retry attempts before failing an upload request",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       description: "The number of seconds to wait before failing an upload request",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :bugsnag_cli_path,
                                       env_name: "BUGSNAG_CLI_PATH",
                                       description: "Path to your bugsnag-cli",
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error! "'#{value}' is not executable" unless FastlaneCore::Helper.executable?(value)
                                       end)
        ]
      end

      private

      # Get any Git options (remote repo, and revision) from the directory
      def self.load_git_remote_options
        git_options = {repository:nil, revision:nil}
        require "git"
        begin
          repo = Git.open(Dir.pwd)
          origin = repo.remotes.detect {|r| r.name == "origin"}
          origin = repo.remotes.first unless origin
          if origin
            git_options[:repository] = origin.url
            git_options[:revision] = repo.revparse("HEAD")
          end
        rescue => e
          UI.verbose("Could not load git options: #{e.message}")
        end
        return git_options
      end

      # Used to get a default configuration file (AndroidManifest.xml or Info.plist)
      def self.default_config_file_path
        case lane_context[:PLATFORM_NAME]
        when nil
          if file_path = default_android_manifest_path
            return file_path
          elsif file_path = FindInfoPlist.default_info_plist_path
            return file_path
          end
        when :android
          if file_path = default_android_manifest_path
            return file_path
          end
        else
          if file_path = FindInfoPlist.default_info_plist_path
            return file_path
          end
        end
      end

      def self.load_config_file_options config_file
        options = {}
        case File.extname(config_file)
        when ".xml"
          options = load_options_from_xml(config_file)
          return options
        when ".plist"
          options = load_options_from_plist(config_file)
          return options
        else
          UI.user_error("File type of '#{config_file}' was not recognised. This should be .xml for Android and .plist for Cococa")
        end
      end

      def self.load_options_from_plist file_path
        options = {}
        plist_getter = Fastlane::Actions::GetInfoPlistValueAction
        bugsnag_dict = plist_getter.run(path: file_path, key: "bugsnag")
        api_key = bugsnag_dict["apiKey"] unless bugsnag_dict.nil?
        release_stage = bugsnag_dict["releaseStage"] unless bugsnag_dict.nil?
        if api_key.nil?
          api_key = plist_getter.run(path: file_path, key: "BugsnagAPIKey")
        end
        options[:apiKey] = api_key
        options[:releaseStage] = release_stage
        options[:appVersion] = plist_getter.run(path: file_path, key: "CFBundleShortVersionString")
        options[:appBundleVersion] = plist_getter.run(path: file_path, key: "CFBundleVersion")
        return options
      end

      def self.default_android_manifest_path
        Dir.glob("./{android/,}{app,}/src/main/AndroidManifest.xml").sort.first
      end

      def self.load_options_from_xml file_path
        options = options_from_android_manifest(file_path)
        build_gradle_path = Dir.glob("{android/,}app/build.gradle").sort.first || Dir.glob("build.gradle").sort.first
        options.merge!(options_from_build_gradle(build_gradle_path)) if build_gradle_path
        return options
      end

      def self.options_from_android_manifest file_path
        options = {}
        begin
          meta_data = parse_android_manifest_options(XmlSimple.xml_in(file_path))
          options[:apiKey] = meta_data["com.bugsnag.android.API_KEY"]
          options[:appVersion] = meta_data["com.bugsnag.android.APP_VERSION"]
          options[:releaseStage] = meta_data["com.bugsnag.android.RELEASE_STAGE"]
        rescue ArgumentError
          nil
        end
        options
      end

      def self.options_from_build_gradle file_path
        options = {}
        begin
          content = File.read(file_path)
          if content =~ /versionCode (\d+)/
            options[:appVersionCode] = $1
          end
          if content =~ /versionName \W(.*)\W[\s]*\n/
            options[:appVersion] = $1
          end
        rescue
        end
        options
      end

      def self.parse_android_manifest_options config_hash
        map_meta_data(get_meta_data(config_hash))
      end

      def self.get_meta_data(object, output = [])
        if object.is_a?(Array)
          object.each do |item|
            output = get_meta_data(item, output)
          end
        elsif object.is_a?(Hash)
          object.each do |key, value|
            if key === "meta-data"
              output << value
            elsif value.is_a?(Array) || value.is_a?(Hash)
              output = get_meta_data(value, output)
            end
          end
        end
        output.flatten
      end

      def self.map_meta_data(meta_data)
        output = {}
        meta_data.each do |hash|
          output[hash["android:name"]] = hash["android:value"]
        end
        output
      end
    end
  end
end
