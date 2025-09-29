fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac build_debug

```sh
[bundle exec] fastlane mac build_debug
```

Build the app in Debug configuration

### mac build_release

```sh
[bundle exec] fastlane mac build_release
```

Build and archive the app for Mac App Store distribution

### mac create_and_sign_release

```sh
[bundle exec] fastlane mac create_and_sign_release
```

Build, archive and sign the app for distribution

### mac distribute_release

```sh
[bundle exec] fastlane mac distribute_release
```

Build, archive, sign and publish the app for distribution

### mac strip_debug_symbols_and_resign

```sh
[bundle exec] fastlane mac strip_debug_symbols_and_resign
```

Strip debug symbols from the binary and resign the app

### mac upload_release_symbols

```sh
[bundle exec] fastlane mac upload_release_symbols
```

Upload the new release to Sentry

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
