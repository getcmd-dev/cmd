# Contributing to track_open_instances

Thank you for your interest in contributing to the track_open_instances project!

This document gives the guidelines for contributing to this project.
These guidelines may not fit every situation. When contributing use your best
judgement.

Propose changes to these guidelines with a pull request.

## How to contribute to track_open_instances

You can contribute in two ways:

1. [Report an issue or make a feature request](#how-to-report-an-issue-or-make-a-feature-request)
2. [Submit a code or documentation change](#how-to-submit-a-code-or-documentation-change)

## How to report an issue or make a feature request

track_open_instances utilizes [GitHub Issues](https://help.github.com/en/github/managing-your-work-on-github/about-issues)
for issue tracking and feature requests.

Report an issue or feature request by [creating a track_open_instances Github issue](https://github.com/main-branch/track_open_instances/issues/new).
Fill in the template to describe the issue or feature request the best you can.

## How to submit a code or documentation change

There is three step process for code or documentation changes:

1. [Commit your changes to a fork of track_open_instances](#commit-changes-to-a-fork-of-track_open_instances)
2. [Create a pull request](#create-a-pull-request)
3. [Get your pull request reviewed](#get-your-pull-request-reviewed)

### Commit changes to a fork of track_open_instances

Make your changes in a fork of the track_open_instances repository.

#### Conventional commits

All commits to this repository MUST follow [the conventional commits
specification](https://www.conventionalcommits.org/en/v1.0.0/#specification). This is
so that release versions can automatically be generated based on the commit messages.
The Continuous Integration workflow will fail if a commit message is not in this
format.

The format for a conventional commit message is:

```Text
<commit-type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Where commit type is one of:

* `feat:` A new feature for the end-user.
* `fix:` A bug fix for the end-user.
* `build:` Changes that affect the build system or external dependencies (e.g.,
  changes to npm, webpack, Docker configurations).
* `chore:` Routine tasks, maintenance, or changes that don't modify source code or
  test files (e.g., updating dependencies, configuring linters).
* `docs:` Changes to documentation only (e.g., updating README, guides, or extensive
  code comments).
* `style:` Changes that do not affect the meaning or logic of the code (e.g.,
  white-space, formatting, fixing linter warnings, missing semi-colons).
* `refactor:` A code change that neither fixes a bug nor adds a feature, but improves
  the code structure, readability, or organization without changing its external
  behavior.
* `perf:` A code change that improves performance.
* `test:` Adding missing tests or correcting existing tests; changes to the test
  environment or configuration.

Backward incompatible changes (aka breaking changes) should append a `!` after the
commit type or add the footer `BREAKING CHANGE:` as shown in the following examples:

```Text
fix!: change the interface to match the requirements
```

```Text
fix: change the interface to match the requirements

BREAKING CHANGE: users will need to add additional, non-default option
```

These commit messages will have the following impact on the release version number:

* Breaking changes (of any commit type) will bump the major version component
* `feat:` commits will bump the minor version component
* `fix:` commits will bump the patch version component

Any other commit types (that are not breaking changes) will not trigger a release.

### Create a pull request

See [this article](https://help.github.com/articles/about-pull-requests/) if you
are not familiar with GitHub Pull Requests.

Follow the instructions in the pull request template.

### Get your pull request reviewed

Code review takes place in a GitHub pull request using the
[the Github pull request review feature](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-request-reviews).

Once your pull request is ready for review, request a review from at least one of the
[code owners](https://github.com/orgs/main-branch/teams/track_open_instances-codeowners/members).

During the review process, you may need to make additional commits which would
need to be squashed. It may also be necessary to rebase to main again if other
changes are merged before your PR.

At least one approval is required from a project maintainer before your pull
request can be merged. The maintainer is responsible for ensuring that the pull
request meets [the project's coding standards](#coding-standards).

## Coding standards

All pull requests must meet these requirements:

### Rebase Merge Strategy

Our project requires a linear commit history, which is achieved by using a
rebase strategy to enable fast-forward merges for all Pull Requests (PRs).

* **Goal:** To integrate PRs without creating extra merge commits, ensuring a clean
  and linear project history. This requires the PR branch to be eligible for a
  [fast-forward
  merge](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging).
* **Commit History:** Before merging, clean up your PR's commit history. Squash
  related changes into logical commits using interactive rebase (`git rebase -i`).
  Aim for a minimal number of meaningful commits that represent distinct steps or
  features.
* **Enable Fast-Forward:** To ensure a fast-forward merge is possible, you must
  rebase your feature branch onto the latest version of the target branch (e.g.,
  `main`) *before* the PR is merged.
  * Example commands (assuming your remote is `origin` and the target branch is
    `main`):

    ```bash
    # Fetch the latest changes from the remote
    git fetch origin

    # Rebase your current branch onto the latest main branch
    git rebase origin/main
    ```

  * You may need to resolve conflicts during the rebase process. After successfully
    rebasing, you'll likely need to force-push your branch (`git push
    --force-with-lease`).

  * You may need to rebase again if other PRs are merged to main.

### Unit tests

- All changes must be accompanied by new or modified RSpec unit tests
- The entire test suite must pass when `bundle exec rake spec` is run from the
  project's local working tree
- The unit test suite must maintain 100% code coverage to pass

### Documentation

- New and updated public methods must have [YARD](https://yardoc.org/)
  documentation added to them
  - [The YARD Cheatsheet](https://gist.github.com/thelastinuit/5984665e6ab69d3c0a413a03602c45be)
    is a good reference
- New and updated public facing features should be documented in the project's
  [README.md](README.md)
- All documentation must pass `yardstick` documentation analysis
- The documentation suite must maintain 100% documentation to pass

### Continuous Integration

- All tests must pass in the project's [Travis CI](https://travis-ci.org/main-branch/track_open_instances)
  build before the pull request will be merged.
- You can simulate what happens in the Travis CI build by running `bundle exec rake` in
  the projects root directory.

### Other Design Guidelines

- Use keyword args with defaults instead of an opts hash

## Licensing

track_open_instances uses [the MIT license](https://choosealicense.com/licenses/mit/) as
declared in the [LICENSE](LICENSE) file.

Licensing is very important to open source projects. It helps ensure the
software continues to be available under the terms that the author desired.
