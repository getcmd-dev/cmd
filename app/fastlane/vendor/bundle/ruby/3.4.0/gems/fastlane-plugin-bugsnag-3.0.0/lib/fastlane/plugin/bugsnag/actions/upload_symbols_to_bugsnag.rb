require_relative "find_info_plist_path"
require_relative "bugsnag_cli"


module Fastlane
  module Actions
    class UploadSymbolsToBugsnagAction < Action
      def self.run(params)
        bugsnag_cli_path = BugsnagCli.get_bugsnag_cli_path(params)
        UI.verbose("Using bugsnag-cli from path: #{bugsnag_cli_path}")

        # If we have not explicitly set an API key through env, or parameter
        # input in Fastfile, find an API key from the Info.plist in config_file param
        api_key = params[:api_key]
        if params[:config_file] && params[:api_key] == nil
          UI.message("Using the API Key from #{params[:config_file]}")
          api_key = options_from_info_plist(params[:config_file])[:apiKey]
        end

        # If verbose flag is enabled (`--verbose`), display the plugin action debug info
        # Store the verbose flag for use in the upload arguments.
        UI.verbose("Uploading dSYMs to Bugsnag with the following parameters:")
        rjust = 30 # set justification width for keys for the list of parameters to output
        params.values.each do |param|
          UI.verbose("  #{param[0].to_s.rjust(rjust)}: #{param[1]}")
        end
        UI.verbose("  #{"SharedValues::DSYM_PATHS".to_s.rjust(rjust)}: #{gym_dsyms? ? Actions.lane_context[SharedValues::DSYM_PATHS] : "not set"}")
        UI.verbose("  #{"SharedValues::DSYM_OUTPUT_PATH".to_s.rjust(rjust)}: #{download_dsym_dsyms? ? Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH] : "not set"}")

        parse_dsym_paths(params[:dsym_path]).each do |dsym_path|
          if dsym_path.end_with?(".zip") or File.directory?(dsym_path)
            args = BugsnagCli.upload_args(
              "\"#{dsym_path}\"",
              params[:upload_url],
              params[:project_root],
              api_key,
              params[:ignore_missing_dwarf],
              params[:ignore_empty_dsym],
              params[:dryrun],
              params[:log_level],
              params[:port],
              params[:retries],
              params[:timeout],
              params[:configuration],
              params[:scheme],
              params[:config_file],
              params[:xcode_project]
            )
            success = BugsnagCli.upload_dsym bugsnag_cli_path, args
            if success
              UI.success("Uploaded dSYMs in #{dsym_path}")
            else
              UI.user_error!("Failed uploading #{dsym_path}")
            end
          else
            UI.user_error!("The specified symbol file path cannot be used: #{dsym_path}")
          end
        end
      end

      def self.description
        "Uploads dSYM debug symbol files to Bugsnag"
      end

      def self.authors
        ["kattrali", "xander-jones"]
      end

      def self.return_value
        nil
      end

      def self.details
        "Takes debug symbol (dSYM) files from a macOS, iOS, or tvOS project and uploads them to Bugsnag to improve stacktrace quality"
      end

      def self.is_supported?(platform)
        [:ios, :mac, :tvos, :catalyst].include?(platform)
      end

      def self.available_options
        validate_dsym_path = proc do |value|
          value.each do |path|
            unless File.exist?(path)
              UI.user_error!("Could not find file at path '#{File.expand_path(path)}'")
            end
            unless File.directory?(path) or path.end_with?(".zip", ".dSYM")
              UI.user_error!("Symbolication file needs to be a directory containing dSYMs, a .dSYM file or a .zip file, got #{File.expand_path(path)}")
            end
          end
        end
        validate_symbol_maps = proc do |path|
          return if path.nil?
          unless File.exist?(path) and File.directory?(path)
            UI.user_error!("Symbol maps file needs to be a directory containing symbol map files")
          end
        end
        validate_api_key = proc do |key|
          return if key.nil?
          unless !key[/\H/] and key.length == 32
            UI.user_error!("API key should be a 32 character hexadecimal string")
          end
        end

        # If the Info.plist is in a default location, we'll get API key here
        # This will be overwritten if you pass in an API key parameter in your
        # Fastfile, or have an API key environment variable set.
        [
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "BUGSNAG_API_KEY",
                                       description: "Bugsnag API Key",
                                       optional: true,
                                       verify_block: validate_api_key),
          FastlaneCore::ConfigItem.new(key: :dsym_path,
                                       type: Array,
                                       env_name: "BUGSNAG_DSYM_PATH",
                                       description: "Path to the dSYM directory, file, or zip to upload",
                                       default_value: default_dsym_paths,
                                       optional: true,
                                       verify_block: validate_dsym_path),
          FastlaneCore::ConfigItem.new(key: :upload_url,
                                       env_name: "BUGSNAG_UPLOAD_URL",
                                       description: "URL of the server receiving uploaded files",
                                       default_value: nil,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :project_root,
                                       env_name: "BUGSNAG_PROJECT_ROOT",
                                       description: "Root path of the project",
                                       default_value: Dir::pwd,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :ignore_missing_dwarf,
                                       env_name: "BUGSNAG_IGNORE_MISSING_DWARF",
                                       description: "Throw warnings instead of errors when a dSYM with missing DWARF data is found",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :ignore_empty_dsym,
                                       env_name: "BUGSNAG_IGNORE_EMPTY_DSYM",
                                       description: "Throw warnings instead of errors when a *.dSYM file is found rather than the expected *.dSYM directory",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :dryrun,
                                       env_name: "BUGSNAG_DRYRUN",
                                       description: "Performs a dry-run of the command without sending any information to BugSnag",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :log_level,
                                       env_name: "BUGSNAG_LOG_LEVEL",
                                       description: "Sets the level of logging to debug, info, warn or fatal",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :port,
                                       env_name: "BUGSNAG_PORT",
                                       description: "The port number for the BugSnag upload server",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :retries,
                                       env_name: "BUGSNAG_RETRIES",
                                       description: "The number of retry attempts before failing an upload request",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       env_name: "BUGSNAG_TIMEOUT",
                                       description: "The number of seconds to wait before failing an upload request",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :configuration,
                                       env_name: "BUGSNAG_CONFIGURATION",
                                       description: "The configuration used to build the application",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :scheme,
                                       env_name: "BUGSNAG_SCHEME",
                                       description: "The name of the Xcode options.Scheme used to build the application",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :config_file,
                                       env_name: "BUGSNAG_CONFIG_FILE",
                                       description: "Info.plist location",
                                       optional: true,
                                       default_value: FindInfoPlist.default_info_plist_path),
          FastlaneCore::ConfigItem.new(key: :xcode_project,
                                       env_name: "BUGSNAG_XCODE_PROJECT",
                                       description: "The path to an Xcode project, workspace or containing directory from which to obtain build information",
                                       optional: true),
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

      def self.options_from_info_plist file_path
        plist_getter = Fastlane::Actions::GetInfoPlistValueAction
        bugsnag_dict = plist_getter.run(path: file_path, key: "bugsnag")
        api_key = bugsnag_dict["apiKey"] unless bugsnag_dict.nil?
        # From v6.0.0 of bugsnag-cocoa, the API key is in 'bugsnag.apiKey',
        # use 'BugsnagAPIKey' as a fallback if it exists (<v6.x.x)
        if api_key.nil?
          api_key = plist_getter.run(path: file_path, key: "BugsnagAPIKey")
        end
        {
          apiKey: api_key,
          config_file: file_path,
        }
      end



      # returns an array of unique dSYM-containing directory paths to upload
      def self.parse_dsym_paths dsym_path
        dsym_path.compact.map do |path|
          path.end_with?(".dSYM") ? File.dirname(path) : path
        end.uniq
      end

      # if input is an Array, return that array, else coerce the input into an array
      def self.coerce_array dsym_path
        dsym_path.is_a?(Array) ? dsym_path : [dsym_path]
      end

      # returns true if `gym` created some dSYMs for us to upload
      # https://docs.fastlane.tools/actions/gym/#lane-variables
      def self.gym_dsyms?
        if defined?(SharedValues::DSYM_OUTPUT_PATH)
          if Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH]
            true
          end
        end
      end

      # returns true if `download_dsyms` created some dSYMs for us to upload
      # https://docs.fastlane.tools/actions/download_dsyms/#lane-variables
      def self.download_dsym_dsyms?
        if defined?(SharedValues::DSYM_PATHS)
          if Actions.lane_context[SharedValues::DSYM_PATHS]
            true
          end
        end
      end

      def self.default_dsym_paths
        vendor_regex = %r{\.\/vendor.*}
        paths = Dir["./**/*.dSYM.zip"].reject{|f| f[vendor_regex] } + Dir["./**/*.dSYM"].reject{|f| f[vendor_regex] } # scrape the sub directories for zips and dSYMs
        paths += coerce_array(Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH]) if gym_dsyms?                     # set by `gym` Fastlane action
        paths += coerce_array(Actions.lane_context[SharedValues::DSYM_PATHS]) if download_dsym_dsyms?                 # set by `download_dsyms` Fastlane action
        parse_dsym_paths(paths.uniq)
      end
    end
  end
end
