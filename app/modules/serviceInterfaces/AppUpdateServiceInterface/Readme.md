# Notes for debugging app update issues

The app uses Sparkle to update itself. It doesn't uses Sparkle's UI but instead installs any available update automatically (unless auto-updates are disable in the settings). When a new update is installed, a widget is shown in the chat window, and the next app launch will use it.

Sparkle's code to update run the app runs in a separate process, that is communicated with over XPC (managed by Sparkle). This means that most relevant logs are not visible by attaching to the app's process in Xcode. You need to use the Console app, or other ways to read system wide logs.

The app reads available updates from https://github.com/getcmd-dev/cmd/raw/refs/heads/main/app/fastlane/appcast.xml as described in the plist.

Bisecting an issue:
- is the new version having issues?
  To test updating to different new versions, one easy way to install different versions is to use a proxy (e.g. Proxyman) and map https://github.com/getcmd-dev/cmd/raw/refs/heads/main/app/fastlane/appcast.xml to a local file that points to the version you want to update to.
- is Sparkle having issues (likely not)?
  - Look for logs in the Console app
  - In you need more logs:
    - Copy Sparkle code locally, make the app use a local package
    - Sparkle's uses a prebuilt framework in SPM. So after changing the local code, you need to rebuild the framework, then rebuild the app. An example of such modification can be found at d7ee348e9c1f3432f6a353f6a34ddfa1fdfbbad9

When a new version of the app is installed, the XPC service, and the Xcode extension that are running might be those of the previous version. They should communicate with each other, realize they are out of date, kill themself and be restarted with the correct version. Logs for both the XPC service and the Xcode extension can also be found in the Console or other system wide log reader.

## Known issues:
- it seems that the error "Timeout: agent connection was never initiated" might happen sporadically. Rebotting the laptop should fix the issue. Not much we can do and the error can be ignored. https://github.com/sparkle-project/Sparkle/discussions/2752
