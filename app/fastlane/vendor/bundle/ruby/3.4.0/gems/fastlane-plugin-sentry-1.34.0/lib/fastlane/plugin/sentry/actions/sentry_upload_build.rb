module Fastlane
  module Actions
    class SentryUploadBuildAction < Action
      def self.run(params)
        Helper::SentryConfig.parse_api_params(params)

        # Verify xcarchive path
        xcarchive_path = params[:xcarchive_path]
        UI.user_error!("Could not find xcarchive at path '#{xcarchive_path}'") unless File.exist?(xcarchive_path)
        UI.user_error!("Path '#{xcarchive_path}' is not an xcarchive") unless File.extname(xcarchive_path) == '.xcarchive'

        command = [
          "build",
          "upload",
          File.absolute_path(xcarchive_path)
        ]

        # Add git-related parameters if provided
        command << "--head-sha" << params[:head_sha] if params[:head_sha]
        command << "--base-sha" << params[:base_sha] if params[:base_sha]
        command << "--vcs-provider" << params[:vcs_provider] if params[:vcs_provider]
        command << "--head-repo-name" << params[:head_repo_name] if params[:head_repo_name]
        command << "--base-repo-name" << params[:base_repo_name] if params[:base_repo_name]
        command << "--head-ref" << params[:head_ref] if params[:head_ref]
        command << "--base-ref" << params[:base_ref] if params[:base_ref]
        command << "--pr-number" << params[:pr_number] if params[:pr_number]
        command << "--build-configuration" << params[:build_configuration] if params[:build_configuration]

        Helper::SentryHelper.call_sentry_cli(params, command)
        UI.success("Successfully uploaded build archive: #{xcarchive_path}")
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload iOS build archive to Sentry with optional git context"
      end

      def self.details
        "This action allows you to upload iOS build archives (.xcarchive) to Sentry with optional git-related parameters for enhanced context including commit SHAs, branch names, repository information, and pull request details."
      end

      def self.available_options
        Helper::SentryConfig.common_api_config_items + [
          FastlaneCore::ConfigItem.new(key: :xcarchive_path,
                                       description: "Path to your iOS build archive (.xcarchive)",
                                       default_value: Actions.lane_context[SharedValues::XCODEBUILD_ARCHIVE],
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not find xcarchive at path '#{value}'") unless File.exist?(value)
                                         UI.user_error!("Path '#{value}' is not an xcarchive") unless File.extname(value) == '.xcarchive'
                                       end),
          FastlaneCore::ConfigItem.new(key: :head_sha,
                                       env_name: "SENTRY_HEAD_SHA",
                                       description: "The SHA of the head of the current branch",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :base_sha,
                                       env_name: "SENTRY_BASE_SHA",
                                       description: "The SHA of the base branch",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :vcs_provider,
                                       env_name: "SENTRY_VCS_PROVIDER",
                                       description: "The version control system provider (e.g., 'github', 'gitlab')",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :head_repo_name,
                                       env_name: "SENTRY_HEAD_REPO_NAME",
                                       description: "The name of the head repository",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :base_repo_name,
                                       env_name: "SENTRY_BASE_REPO_NAME",
                                       description: "The name of the base repository",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :head_ref,
                                       env_name: "SENTRY_HEAD_REF",
                                       description: "The name of the head branch",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :base_ref,
                                       env_name: "SENTRY_BASE_REF",
                                       description: "The name of the base branch",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :pr_number,
                                       env_name: "SENTRY_PR_NUMBER",
                                       description: "The pull request number",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :build_configuration,
                                       env_name: "SENTRY_BUILD_CONFIGURATION",
                                       description: "The build configuration (e.g., 'Release', 'Debug')",
                                       optional: true,
                                       is_string: true)
        ]
      end

      def self.return_value
        nil
      end

      def self.authors
        ["runningcode"]
      end

      def self.is_supported?(platform)
        [:ios].include?(platform)
      end
    end
  end
end
