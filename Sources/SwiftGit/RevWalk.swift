import Foundation
import Libgit2Bindings

public struct SortMode: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let none: SortMode = []
    public static let topological = SortMode(rawValue: 1 << 0)
    public static let time = SortMode(rawValue: 1 << 1)
    public static let reverse = SortMode(rawValue: 1 << 2)

    public var description: String {
        if rawValue == 0 {
            return "none"
        }

        let labels: [(SortMode, String)] = [
            (.topological, "topological"),
            (.time, "time"),
            (.reverse, "reverse")
        ]

        return labels.compactMap { contains($0.0) ? $0.1 : nil }.joined(separator: ", ")
    }
}

public final class RevWalk {
    private let repository: Repository
    internal let pointer: OpaquePointer

    internal init(repository: Repository, pointer: OpaquePointer) {
        self.repository = repository
        self.pointer = pointer
    }

    deinit {
        git_revwalk_free(pointer)
    }

    public func reset() throws {
        try check(git_revwalk_reset(pointer), context: "git_revwalk_reset")
    }

    public func sort(by mode: SortMode) throws {
        try check(git_revwalk_sorting(pointer, mode.rawValue), context: "git_revwalk_sorting")
    }

    public func pushHead() throws {
        try check(git_revwalk_push_head(pointer), context: "git_revwalk_push_head")
    }

    public func push(_ oid: OID) throws {
        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(git_revwalk_push(pointer, oidPointer), context: "git_revwalk_push")
        }
    }

    public func push(reference name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_revwalk_push_ref(pointer, namePointer), context: "git_revwalk_push_ref")
        }
    }

    public func push(range: String) throws {
        _ = try range.withCString { rangePointer in
            try check(git_revwalk_push_range(pointer, rangePointer), context: "git_revwalk_push_range")
        }
    }

    public func hide(_ oid: OID) throws {
        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(git_revwalk_hide(pointer, oidPointer), context: "git_revwalk_hide")
        }
    }

    public func hide(reference name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_revwalk_hide_ref(pointer, namePointer), context: "git_revwalk_hide_ref")
        }
    }

    public func nextOID() throws -> OID? {
        var oid = git_oid()
        let result = git_revwalk_next(&oid, pointer)

        if result == GitErrorCode.iterationOver.rawValue {
            return nil
        }

        try check(result, context: "git_revwalk_next")
        return OID(oid)
    }

    public func nextCommit() throws -> Commit? {
        guard let oid = try nextOID() else {
            return nil
        }

        return try repository.commit(oid)
    }

    public func oids(limit: Int? = nil) throws -> [OID] {
        var values: [OID] = []
        values.reserveCapacity(limit ?? 16)

        while let oid = try nextOID() {
            values.append(oid)

            if let limit, values.count >= limit {
                break
            }
        }

        return values
    }

    public func commits(limit: Int? = nil) throws -> [Commit] {
        try oids(limit: limit).map(repository.commit)
    }
}

extension Repository {
    public func revisionWalker(sorting: SortMode = [.time]) throws -> RevWalk {
        var walker: OpaquePointer?
        try check(git_revwalk_new(&walker, pointer), context: "git_revwalk_new")

        guard let walker else {
            throw makeMissingPointerError(function: "git_revwalk_new")
        }

        let revisionWalker = RevWalk(repository: self, pointer: walker)
        try revisionWalker.sort(by: sorting)
        return revisionWalker
    }

    public func history(
        startingAt reference: String = "HEAD",
        sorting: SortMode = [.time],
        limit: Int? = nil
    ) throws -> [Commit] {
        let walker = try revisionWalker(sorting: sorting)

        if reference == "HEAD" {
            try walker.pushHead()
        } else {
            try walker.push(reference: reference)
        }

        return try walker.commits(limit: limit)
    }

    public func aheadBehind(local: OID, upstream: OID) throws -> (ahead: Int, behind: Int) {
        var ahead = 0
        var behind = 0

        _ = try local.withUnsafeGitOID { localPointer in
            try upstream.withUnsafeGitOID { upstreamPointer in
                try check(
                    git_graph_ahead_behind(&ahead, &behind, pointer, localPointer, upstreamPointer),
                    context: "git_graph_ahead_behind"
                )
            }
        }

        return (ahead, behind)
    }

    public func isDescendant(_ commit: OID, of ancestor: OID) throws -> Bool {
        let result = commit.withUnsafeGitOID { commitPointer in
            ancestor.withUnsafeGitOID { ancestorPointer in
                git_graph_descendant_of(pointer, commitPointer, ancestorPointer)
            }
        }

        if result < 0 {
            throw GitError.lastError(code: result, context: "git_graph_descendant_of")
        }

        return result > 0
    }

    internal func objectPointer(for revision: String) throws -> OpaquePointer {
        var object: OpaquePointer?

        _ = try revision.withCString { revisionPointer in
            try check(git_revparse_single(&object, pointer, revisionPointer), context: "git_revparse_single")
        }

        guard let object else {
            throw makeMissingPointerError(function: "git_revparse_single")
        }

        return object
    }

    internal func objectPointer(
        for oid: OID,
        type: ObjectType = .any
    ) throws -> OpaquePointer {
        var object: OpaquePointer?

        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(
                git_object_lookup(&object, pointer, oidPointer, type.gitObjectType),
                context: "git_object_lookup"
            )
        }

        guard let object else {
            throw makeMissingPointerError(function: "git_object_lookup")
        }

        return object
    }
}
