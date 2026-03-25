import Foundation
import Testing
@testable import SwiftGit

@Suite("Checkout")
struct CheckoutTests {
    @Test
    func failedBranchCheckoutDoesNotMoveHEAD() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repositoryURL = root.appendingPathComponent("repo", isDirectory: true)
        let repository = try Repository.create(at: repositoryURL, initialBranch: "main")
        let author = Signature(name: "Bri", email: "bri@example.com")

        let fileURL = repositoryURL.appendingPathComponent("Tracked.swift")
        try "print(\"main\")\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let index = try repository.index()
        try index.add(path: "Tracked.swift")
        let initialCommit = try repository.commit(message: "Initial", author: author)

        _ = try repository.createBranch(named: "feature", at: initialCommit)
        try repository.checkout(branch: "feature", strategy: .force)

        try "print(\"feature\")\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try index.add(path: "Tracked.swift")
        _ = try repository.commit(message: "Feature", author: author)

        try repository.checkout(branch: "main", strategy: .force)
        try "print(\"dirty\")\n".write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(throws: Error.self) {
            try repository.checkout(branch: "feature")
        }

        #expect(try repository.headReference().shorthand == "main")
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "print(\"dirty\")\n")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
