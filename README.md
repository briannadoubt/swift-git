[![CI](https://github.com/briannadoubt/swift-git/actions/workflows/ci.yml/badge.svg)](https://github.com/briannadoubt/swift-git/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)

# SwiftGit

`SwiftGit` is a Swift package that wraps `libgit2` in a Swift-first API that stays close to Git’s real object model while hiding pointer ownership and C interop details.

## Requirements

- macOS 15+, iOS 18+, visionOS 2+
- Xcode 16.3+ / Swift 6.2+

On macOS, `SwiftGit` links against a system `libgit2`:

```bash
brew install libgit2 pkgconf
```

On iOS and visionOS, the package ships a bundled binary dependency.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/briannadoubt/swift-git.git", branch: "main")
]
```

```swift
.product(name: "SwiftGit", package: "swift-git")
```

## Example

```swift
import Foundation
import SwiftGit

let repositoryURL = URL(fileURLWithPath: "/tmp/example-repo", isDirectory: true)
let repository = try Git.createRepository(at: repositoryURL, initialBranch: "main")
let config = try repository.config()

try config.set("SwiftGit", for: "user.name")
try config.set("git@example.com", for: "user.email")

try "hello from SwiftGit\n".write(
    to: repositoryURL.appendingPathComponent("README.md"),
    atomically: true,
    encoding: .utf8
)

let index = try repository.index()
try index.add(path: "README.md")

let commit = try repository.commit(
    message: "Initial commit",
    author: try repository.defaultSignature()
)

let branch = try repository.createBranch(named: "feature", at: commit)
let tag = try repository.createAnnotatedTag(
    named: "v1.0.0",
    target: "HEAD",
    message: "First release",
    tagger: try repository.defaultSignature()
)

print(commit.id)
print(branch.name)
print(tag.name)
```

## Capabilities

- repository lifecycle, opening, cloning, and discovery
- commits, trees, blobs, indexes, status, and diff workflows
- config read and write APIs plus default signatures
- local branches, upstreams, renames, deletes, and ahead/behind comparisons
- lightweight and annotated tags
- remotes, fetch, checkout, HEAD switching, and revision walking

## Testing

```bash
swift test
```

## License

MIT. See [LICENSE](LICENSE).
