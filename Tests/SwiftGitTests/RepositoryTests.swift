import Foundation
import Testing
@testable import SwiftGit

@Suite("Repository")
struct RepositoryTests {
    @Test
    func repositoryLifecycle() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repositoryURL = root.appendingPathComponent("repo", isDirectory: true)
        let repository = try Repository.create(at: repositoryURL, initialBranch: "main")

        #expect(repository.isBare == false)
        #expect(try repository.isHEADDetached == false)
        #expect(try repository.isHEADUnborn == true)
        #expect(repository.state == .none)

        let readmeURL = repositoryURL.appendingPathComponent("README.md")
        try "hello\n".write(to: readmeURL, atomically: true, encoding: .utf8)

        let index = try repository.index()
        try index.add(path: "README.md")
        try index.write()

        let signature = Signature(
            name: "Bri",
            email: "bri@example.com",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            timeZoneOffsetMinutes: 0
        )

        let commit = try repository.commit(
            message: "Initial commit\n\nBody text",
            author: signature
        )

        #expect(commit.summary == "Initial commit")
        #expect(commit.body == "Body text")
        #expect(commit.parentCount == 0)
        #expect(try repository.headCommit().id == commit.id)
        #expect(try repository.headReference().shorthand == "main")

        let opened = try Git.open(repositoryURL)
        #expect(try opened.headCommit().id == commit.id)

        let references = try repository.references()
        #expect(references.contains { $0.name == "refs/heads/main" })

        let tree = try commit.tree()
        let entry = try #require(tree.entry(named: "README.md"))
        let blob = try repository.blob(entry.oid)

        #expect(blob.string() == "hello\n")

        try "hello\nworld\n".write(to: readmeURL, atomically: true, encoding: .utf8)

        let status = try repository.status()
        #expect(
            status.contains {
                $0.path == "README.md" && $0.status.contains(.workTreeModified)
            }
        )

        let diff = try repository.diffToWorkingDirectory(from: tree)
        let patch = try diff.patch()
        let stats = try diff.stats()

        #expect(patch.contains("README.md"))
        #expect(stats.filesChanged == 1)
        #expect(stats.insertions >= 1)
    }

    @Test
    func cloneAndDiscover() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let originURL = root.appendingPathComponent("origin", isDirectory: true)
        let cloneURL = root.appendingPathComponent("clone", isDirectory: true)
        let nestedURL = cloneURL.appendingPathComponent("Sources/Nested", isDirectory: true)

        let origin = try Repository.create(at: originURL, initialBranch: "main")
        try "content\n".write(
            to: originURL.appendingPathComponent("file.txt"),
            atomically: true,
            encoding: .utf8
        )

        let index = try origin.index()
        try index.add(path: "file.txt")

        let signature = Signature(name: "Bri", email: "bri@example.com")
        let originCommit = try origin.commit(message: "seed", author: signature)

        let clone = try Repository.clone(from: originURL.path, to: cloneURL.path)
        #expect(try clone.headCommit().id == originCommit.id)

        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        let discovered = try Git.discoverRepository(startingAt: nestedURL.path)

        #expect(discovered.contains(".git"))
    }

    @Test
    func writesBlobObjects() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try Repository.create(
            at: root.appendingPathComponent("repo", isDirectory: true),
            initialBranch: "main"
        )

        let payload = Data("blob payload".utf8)
        let oid = try repository.writeBlob(payload)
        let blob = try repository.blob(oid)

        #expect(blob.data == payload)
        #expect(blob.string() == "blob payload")
    }

    @Test
    func configBranchesHistoryAndTags() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repositoryURL = root.appendingPathComponent("repo", isDirectory: true)
        let repository = try Repository.create(at: repositoryURL, initialBranch: "main")

        let config = try repository.config()
        try config.set("Bri", for: "user.name")
        try config.set("bri@example.com", for: "user.email")
        try config.set(true, for: "swiftgit.enabled")
        try config.set(Int32(42), for: "swiftgit.answer")

        let snapshot = try repository.configSnapshot()
        #expect(try snapshot.string("user.name") == "Bri")
        #expect(try config.bool("swiftgit.enabled") == true)
        #expect(try config.int32("swiftgit.answer") == 42)
        #expect(try repository.defaultSignature().email == "bri@example.com")

        let documentURL = repositoryURL.appendingPathComponent("notes.txt")
        try "one\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let index = try repository.index()
        try index.add(path: "notes.txt")

        let firstCommit = try repository.commit(
            message: "First",
            author: Signature(name: "Bri", email: "bri@example.com")
        )

        let feature = try repository.createBranch(named: "feature", at: firstCommit)
        try feature.setUpstream("main")
        #expect(try feature.upstreamName == "refs/heads/main")

        try "two\n".write(to: documentURL, atomically: true, encoding: .utf8)
        try index.add(path: "notes.txt")

        let secondCommit = try repository.commit(
            message: "Second",
            author: Signature(name: "Bri", email: "bri@example.com")
        )

        let mainBranch = try repository.branch(named: "main")
        let comparison = try feature.aheadBehind(against: mainBranch)
        #expect(comparison.ahead == 0)
        #expect(comparison.behind == 1)
        #expect(try repository.isDescendant(secondCommit.id, of: firstCommit.id) == true)

        let walker = try repository.revisionWalker(sorting: [.topological, .time])
        try walker.pushHead()
        let history = try walker.commits(limit: 2)
        #expect(history.map(\.id) == [secondCommit.id, firstCommit.id])

        let localBranches = try repository.branches(.local).map(\.name)
        #expect(localBranches.contains("main"))
        #expect(localBranches.contains("feature"))

        let release = try repository.createAnnotatedTag(
            named: "v1.0.0",
            target: "HEAD",
            message: "Release 1",
            tagger: Signature(name: "Bri", email: "bri@example.com")
        )
        let snapshotTag = try repository.createLightweightTag(
            named: "snapshot",
            target: firstCommit.id.description
        )

        #expect(release.isAnnotated == true)
        #expect(release.message == "Release 1")
        #expect(release.targetID == secondCommit.id)
        #expect(snapshotTag.isAnnotated == false)
        #expect(snapshotTag.targetID == firstCommit.id)

        let tags = try repository.tags()
        #expect(tags.map(\.name).contains("v1.0.0"))
        #expect(tags.map(\.name).contains("snapshot"))
    }

    @Test
    func remotesFetchAndCheckout() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let originURL = root.appendingPathComponent("origin", isDirectory: true)
        let cloneURL = root.appendingPathComponent("clone", isDirectory: true)

        let origin = try Repository.create(at: originURL, initialBranch: "main")
        let originConfig = try origin.config()
        try originConfig.set("Bri", for: "user.name")
        try originConfig.set("bri@example.com", for: "user.email")

        let originFile = originURL.appendingPathComponent("file.txt")
        try "one\n".write(to: originFile, atomically: true, encoding: .utf8)

        let originIndex = try origin.index()
        try originIndex.add(path: "file.txt")
        _ = try origin.commit(message: "one", author: Signature(name: "Bri", email: "bri@example.com"))

        let clone = try Repository.clone(from: originURL.path, to: cloneURL.path)
        let remoteNames = try clone.remoteNames()
        #expect(remoteNames.contains("origin"))

        let originRemote = try clone.remote(named: "origin")
        #expect(originRemote.url == originURL.path)
        #expect(try originRemote.fetchRefspecs.isEmpty == false)

        try "two\n".write(to: originFile, atomically: true, encoding: .utf8)
        try originIndex.add(path: "file.txt")
        let secondOriginCommit = try origin.commit(
            message: "two",
            author: Signature(name: "Bri", email: "bri@example.com")
        )

        try originRemote.fetch(reflogMessage: "sync origin")
        #expect(try clone.commit("refs/remotes/origin/main").id == secondOriginCommit.id)

        let feature = try clone.createBranch(named: "feature", from: "refs/remotes/origin/main")
        let experiment = try clone.renameBranch(feature, to: "experiment")

        try clone.checkout(branch: "experiment", strategy: [.force])
        #expect(try clone.headReference().shorthand == "experiment")
        #expect(try String(contentsOf: cloneURL.appendingPathComponent("file.txt"), encoding: .utf8) == "two\n")

        try clone.checkout(branch: "main", strategy: [.force])
        #expect(try clone.headReference().shorthand == "main")
        #expect(try String(contentsOf: cloneURL.appendingPathComponent("file.txt"), encoding: .utf8) == "one\n")

        try clone.deleteBranch(experiment)
        let remainingBranches = try clone.branches(.local).map(\.name)
        #expect(remainingBranches.contains("main"))
        #expect(remainingBranches.contains("experiment") == false)
    }

    @Test
    func diffScopesExposePatchMetadataAndUntrackedContent() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repositoryURL = root.appendingPathComponent("repo", isDirectory: true)
        let repository = try Repository.create(at: repositoryURL, initialBranch: "main")
        let author = Signature(name: "Bri", email: "bri@example.com")

        let trackedURL = repositoryURL.appendingPathComponent("Tracked.swift")
        try "print(\"base\")\n".write(to: trackedURL, atomically: true, encoding: .utf8)

        let initialIndex = try repository.index()
        try initialIndex.add(path: "Tracked.swift")
        _ = try repository.commit(message: "Initial", author: author)

        try "print(\"updated\")\n".write(to: trackedURL, atomically: true, encoding: .utf8)
        try "print(\"untracked\")\n".write(
            to: repositoryURL.appendingPathComponent("Untracked.swift"),
            atomically: true,
            encoding: .utf8
        )

        let diff = try repository.diffIndexToWorkingDirectory(
            options: DiffOptions(
                includeUntracked: true,
                recurseUntrackedDirectories: true,
                showUntrackedContent: true
            )
        )

        let statuses = Dictionary(uniqueKeysWithValues: diff.deltas().compactMap { delta in
            delta.path.map { ($0, delta.kind) }
        })
        #expect(statuses["Tracked.swift"] == .modified)
        #expect(statuses["Untracked.swift"] == .untracked)

        let patches = try diff.patches()
        let trackedPatch = try #require(patches.first { $0.delta.path == "Tracked.swift" })
        let untrackedPatch = try #require(patches.first { $0.delta.path == "Untracked.swift" })

        #expect(trackedPatch.addedLineCount == 1)
        #expect(trackedPatch.removedLineCount == 1)
        #expect(trackedPatch.isBinary == false)
        #expect(
            trackedPatch.hunks.flatMap(\.lines).contains {
                $0.origin == .addition && $0.text == "print(\"updated\")"
            }
        )
        #expect(
            trackedPatch.hunks.flatMap(\.lines).contains {
                $0.origin == .deletion && $0.text == "print(\"base\")"
            }
        )

        #expect(untrackedPatch.delta.kind == .untracked)
        #expect(untrackedPatch.addedLineCount == 1)
        #expect(untrackedPatch.removedLineCount == 0)
        #expect(untrackedPatch.isBinary == false)
        #expect(untrackedPatch.text.contains("diff --git"))
        #expect(
            untrackedPatch.hunks.flatMap(\.lines).contains {
                $0.origin == .addition && $0.text == "print(\"untracked\")"
            }
        )
    }

    @Test
    func mergeBaseAndTreeToIndexDiffsSupportBranchAndRenameWorkflows() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repositoryURL = root.appendingPathComponent("repo", isDirectory: true)
        let repository = try Repository.create(at: repositoryURL, initialBranch: "main")
        let author = Signature(name: "Bri", email: "bri@example.com")

        let baseURL = repositoryURL.appendingPathComponent("Base.swift")
        try "print(\"base\")\n".write(to: baseURL, atomically: true, encoding: .utf8)

        let index = try repository.index()
        try index.add(path: "Base.swift")
        let baseCommit = try repository.commit(message: "Base", author: author)

        _ = try repository.createBranch(named: "feature", at: baseCommit)

        try "print(\"main\")\n".write(to: baseURL, atomically: true, encoding: .utf8)
        try index.add(path: "Base.swift")
        let mainCommit = try repository.commit(message: "Main change", author: author)

        try repository.checkout(branch: "feature", strategy: [.force])
        try "print(\"feature\")\n".write(to: baseURL, atomically: true, encoding: .utf8)
        try index.add(path: "Base.swift")
        let featureCommit = try repository.commit(message: "Feature change", author: author)

        let mergeBase = try repository.mergeBase(between: mainCommit.id, and: featureCommit.id)
        #expect(mergeBase == baseCommit.id)

        let branchDiff = try repository.diff(
            between: try repository.commit(mergeBase).tree(),
            and: try repository.commit(featureCommit.id).tree()
        )
        let branchStats = try branchDiff.stats()
        let branchPatch = try branchDiff.patch()

        #expect(branchStats.filesChanged == 1)
        #expect(branchPatch.contains("print(\"feature\")"))

        try repository.checkout(branch: "main", strategy: [.force])
        let renamedURL = repositoryURL.appendingPathComponent("Renamed.swift")
        try FileManager.default.moveItem(at: baseURL, to: renamedURL)
        try "print(\"main\")\nprint(\"rename\")\n".write(to: renamedURL, atomically: true, encoding: .utf8)

        let stagedIndex = try repository.index()
        try stagedIndex.remove(path: "Base.swift")
        try stagedIndex.add(path: "Renamed.swift")
        try stagedIndex.write()

        let renameDiff = try repository.diffTreeToIndex(from: try repository.headCommit().tree())
        try renameDiff.findSimilar()
        let renameDelta = try #require(renameDiff.deltas().first)

        #expect(renameDelta.kind == .renamed)
        #expect(renameDelta.oldFile.path == "Base.swift")
        #expect(renameDelta.newFile.path == "Renamed.swift")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftGitTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
