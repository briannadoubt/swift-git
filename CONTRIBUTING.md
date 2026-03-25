# Contributing to SwiftGit

## Setup

- Use Xcode 16.3 or newer with Swift 6.2 support.
- On macOS, install `libgit2` and `pkgconf` before building or testing.
- Keep API additions aligned with Git and libgit2 terminology unless there is a strong Swift ergonomics reason to diverge.

## Local Checks

- Run `swift build`
- Run `swift test`

## Change Guidelines

- Add or update regression tests for repository workflows, reference handling, diffs, or checkout behavior.
- Preserve explicit ownership rules around underlying libgit2 handles.
- Document new public APIs or platform support changes in `README.md`.

## Pull Requests

- Explain the workflow covered by the change.
- Call out any libgit2 assumptions or platform conditionals.
- Include migration notes if a public API shape changes.
