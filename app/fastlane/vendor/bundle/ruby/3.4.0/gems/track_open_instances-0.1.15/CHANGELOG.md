# Change Log

## [0.1.15](https://github.com/main-branch/track_open_instances/compare/v0.1.14...v0.1.15) (2025-04-17)


### Other Changes

* Configure release-please to includes all changes in the CHANGELOG ([8db0fac](https://github.com/main-branch/track_open_instances/commit/8db0facc3cfc14833dda616d14b03695c3fdf5f0))
* Do not enforce conventional commits for release PR ([64f2749](https://github.com/main-branch/track_open_instances/commit/64f274979de50dfc4b4e0b88e78d147a12c5061f))

## [0.1.14](https://github.com/main-branch/track_open_instances/compare/v0.1.13...v0.1.14) (2025-04-16)


### Bug Fixes

* Do not trigger CI workflow for release PRs ([635d8af](https://github.com/main-branch/track_open_instances/commit/635d8af71bf305bac312f2db1b99c0eb3974a945))

## [0.1.13](https://github.com/main-branch/track_open_instances/compare/v0.1.12...v0.1.13) (2025-04-16)


### Bug Fixes

* Do not trigger build workflows when merging to main ([1799b54](https://github.com/main-branch/track_open_instances/commit/1799b54bc3d91dfef45b2131feb350b7dee08879))

## [0.1.12](https://github.com/main-branch/track_open_instances/compare/v0.1.11...v0.1.12) (2025-04-15)


### Bug Fixes

* Change the release PR title to be more user friendly ([0fb9ce2](https://github.com/main-branch/track_open_instances/commit/0fb9ce2cbac10a4efdf44d47bd0cf316d99fc410))
* Remove pull request title pattern from release configuration ([2460dde](https://github.com/main-branch/track_open_instances/commit/2460ddeabd975b42925daf0572220ef6cbe208fd))

## [0.1.11](https://github.com/main-branch/track_open_instances/compare/v0.1.10...v0.1.11) (2025-04-15)


### Features

* Initial implementation of TrackOpenInstances ([f0fb459](https://github.com/main-branch/track_open_instances/commit/f0fb459b35173635900e0d6f1a7bb7e3188c6914))


### Bug Fixes

* Add qlty configuration in order to run qlty checks locally ([56811ca](https://github.com/main-branch/track_open_instances/commit/56811ca9f9eab200780dd80b9946402db85a5dc0))
* Auto push new version of gem to rubygems.org ([4740681](https://github.com/main-branch/track_open_instances/commit/4740681f90dad73c36622cbf0a23e43713742d0c))
* Fix continuous integration workflow issues reported by qlty.sh ([e83546a](https://github.com/main-branch/track_open_instances/commit/e83546ac4038581d9fcf445f0fb82f098bb4ff2d))
* Remove integration to CodeClimate and qlty ([47b0c09](https://github.com/main-branch/track_open_instances/commit/47b0c090303ff68a003a52b4b363fdb7528e289b))
* Update TrackOpenInstances docs and report ([7575c1f](https://github.com/main-branch/track_open_instances/commit/7575c1f5a3947ff3e66e79f099e7dcdd6203e653))

## v0.1.0 (2025-04-08)

[Full Changelog](https://github.com/main-branch/track_open_instances/compare/f0fb459..v0.1.0)

Changes:

- f2d5318 chore: remove radarline-ruby from qlty checks
- 177eba8 chore: fix formatting errors reported by `qlty fmt`
- 943359f build: remove rubocop plugin from qlty
- 476f271 chore: integrate yamllint
- 56811ca fix: add qlty configuration in order to run qlty checks locally
- e83546a fix: fix continuous integration workflow issues reported by qlty.sh
- 6f67aed test: add predicate methods to determine the Ruby engine and platform
- 34e3829 build: generate JSON coverage report for qlty.sh coverage reporting
- 9db2052 docs: update README links
- 937a971 build: update code coverage reporting
- f0fb459 feat: initial implementation of TrackOpenInstances
