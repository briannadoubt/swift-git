import Foundation
import Libgit2Bindings

public final class Commit {
    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_commit_free(pointer)
    }

    public var id: OID {
        OID(git_commit_id(pointer).pointee)
    }

    public var messageEncoding: String? {
        gitString(git_commit_message_encoding(pointer))
    }

    public var message: String? {
        gitString(git_commit_message(pointer))
    }

    public var summary: String? {
        gitString(git_commit_summary(pointer))
    }

    public var body: String? {
        gitString(git_commit_body(pointer))
    }

    public var rawHeader: String? {
        gitString(git_commit_raw_header(pointer))
    }

    public var time: Date {
        Date(timeIntervalSince1970: TimeInterval(git_commit_time(pointer)))
    }

    public var timeZoneOffsetMinutes: Int {
        Int(git_commit_time_offset(pointer))
    }

    public var author: Signature {
        Signature(git_commit_author(pointer)!)
    }

    public var committer: Signature {
        Signature(git_commit_committer(pointer)!)
    }

    public var treeID: OID {
        OID(git_commit_tree_id(pointer).pointee)
    }

    public var parentCount: Int {
        Int(git_commit_parentcount(pointer))
    }

    public func tree() throws -> Tree {
        var tree: OpaquePointer?
        try check(git_commit_tree(&tree, pointer), context: "git_commit_tree")

        guard let tree else {
            throw makeMissingPointerError(function: "git_commit_tree")
        }

        return Tree(pointer: tree)
    }

    public func parent(at index: Int) throws -> Commit {
        var parent: OpaquePointer?
        try check(git_commit_parent(&parent, pointer, UInt32(index)), context: "git_commit_parent")

        guard let parent else {
            throw makeMissingPointerError(function: "git_commit_parent")
        }

        return Commit(pointer: parent)
    }

    public func parents() throws -> [Commit] {
        try (0..<parentCount).map(parent(at:))
    }
}
