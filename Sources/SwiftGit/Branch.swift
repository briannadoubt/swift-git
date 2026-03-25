import Foundation
import Libgit2Bindings

public enum BranchType: Int32, CustomStringConvertible, Sendable {
    case local = 1
    case remote = 2

    public var description: String {
        switch self {
        case .local: return "local"
        case .remote: return "remote"
        }
    }

    internal init?(gitBranchType: git_branch_t) {
        self.init(rawValue: rawInt32(of: gitBranchType))
    }

    internal init?(referenceName: String) {
        if referenceName.hasPrefix("refs/heads/") {
            self = .local
        } else if referenceName.hasPrefix("refs/remotes/") {
            self = .remote
        } else {
            return nil
        }
    }
}

public struct BranchFilter: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let local = BranchFilter(rawValue: 1 << 0)
    public static let remote = BranchFilter(rawValue: 1 << 1)
    public static let all: BranchFilter = [.local, .remote]

    public var description: String {
        switch self {
        case .local: return "local"
        case .remote: return "remote"
        case .all: return "all"
        default: return "custom(\(rawValue))"
        }
    }

    internal var gitBranchType: git_branch_t {
        switch self {
        case .local:
            return GIT_BRANCH_LOCAL
        case .remote:
            return GIT_BRANCH_REMOTE
        default:
            return GIT_BRANCH_ALL
        }
    }
}

public final class Branch {
    private let repository: Repository
    internal let reference: Reference
    public let type: BranchType

    internal init(repository: Repository, reference: Reference, type: BranchType) {
        self.repository = repository
        self.reference = reference
        self.type = type
    }

    public var name: String {
        var namePointer: UnsafePointer<CChar>?
        let result = git_branch_name(&namePointer, reference.pointer)

        if result == 0, let namePointer {
            return String(cString: namePointer)
        }

        return reference.shorthand
    }

    public var referenceName: String {
        reference.name
    }

    public var shorthand: String {
        reference.shorthand
    }

    public var target: OID? {
        if let target = reference.target {
            return target
        }

        return try? reference.resolved().target
    }

    public var isHEAD: Bool {
        get throws {
            try check(git_branch_is_head(reference.pointer), context: "git_branch_is_head") > 0
        }
    }

    public func upstream() throws -> Branch? {
        var upstreamReference: OpaquePointer?
        let result = git_branch_upstream(&upstreamReference, reference.pointer)

        if result == GitErrorCode.notFound.rawValue {
            return nil
        }

        try check(result, context: "git_branch_upstream")

        guard let upstreamReference else {
            throw makeMissingPointerError(function: "git_branch_upstream")
        }

        let reference = Reference(pointer: upstreamReference)
        let type = BranchType(referenceName: reference.name) ?? .remote
        return Branch(repository: repository, reference: reference, type: type)
    }

    public var upstreamName: String? {
        get throws {
            do {
                let (_, value) = try withGitBuffer { buffer in
                    _ = try referenceName.withCString { referenceNamePointer in
                        try check(
                            git_branch_upstream_name(buffer, repository.pointer, referenceNamePointer),
                            context: "git_branch_upstream_name"
                        )
                    }
                }

                return value
            } catch let error as GitError where error.knownCode == .notFound {
                return nil
            }
        }
    }

    public var upstreamRemoteName: String? {
        get throws {
            do {
                let (_, value) = try withGitBuffer { buffer in
                    _ = try referenceName.withCString { referenceNamePointer in
                        try check(
                            git_branch_upstream_remote(buffer, repository.pointer, referenceNamePointer),
                            context: "git_branch_upstream_remote"
                        )
                    }
                }

                return value
            } catch let error as GitError where error.knownCode == .notFound {
                return nil
            }
        }
    }

    public func setUpstream(_ branchName: String?) throws {
        _ = try withOptionalCString(branchName) { branchNamePointer in
            try check(git_branch_set_upstream(reference.pointer, branchNamePointer), context: "git_branch_set_upstream")
        }
    }

    public func aheadBehind(against upstream: Branch) throws -> (ahead: Int, behind: Int) {
        guard let localTarget = target else {
            throw GitError(
                code: GitErrorCode.invalid.rawValue,
                category: .reference,
                message: "Branch \(name) does not point to an object id",
                context: "aheadBehind"
            )
        }

        guard let upstreamTarget = upstream.target else {
            throw GitError(
                code: GitErrorCode.invalid.rawValue,
                category: .reference,
                message: "Branch \(upstream.name) does not point to an object id",
                context: "aheadBehind"
            )
        }

        return try repository.aheadBehind(local: localTarget, upstream: upstreamTarget)
    }
}

extension Repository {
    public func branch(named name: String, type: BranchType = .local) throws -> Branch {
        var reference: OpaquePointer?

        _ = try name.withCString { namePointer in
            try check(git_branch_lookup(&reference, pointer, namePointer, type == .local ? GIT_BRANCH_LOCAL : GIT_BRANCH_REMOTE), context: "git_branch_lookup")
        }

        guard let reference else {
            throw makeMissingPointerError(function: "git_branch_lookup")
        }

        return Branch(repository: self, reference: Reference(pointer: reference), type: type)
    }

    public func branches(_ filter: BranchFilter = .local) throws -> [Branch] {
        var iterator: OpaquePointer?
        try check(git_branch_iterator_new(&iterator, pointer, filter.gitBranchType), context: "git_branch_iterator_new")

        guard let iterator else {
            throw makeMissingPointerError(function: "git_branch_iterator_new")
        }

        defer { git_branch_iterator_free(iterator) }

        var branches: [Branch] = []

        while true {
            var reference: OpaquePointer?
            var branchType = GIT_BRANCH_LOCAL
            let result = git_branch_next(&reference, &branchType, iterator)

            if result == GitErrorCode.iterationOver.rawValue {
                break
            }

            try check(result, context: "git_branch_next")

            if let reference {
                let type = BranchType(gitBranchType: branchType) ?? .local
                branches.append(
                    Branch(repository: self, reference: Reference(pointer: reference), type: type)
                )
            }
        }

        return branches
    }

    @discardableResult
    public func createBranch(
        named name: String,
        at commit: Commit,
        force: Bool = false
    ) throws -> Branch {
        var reference: OpaquePointer?

        _ = try name.withCString { namePointer in
            try check(
                git_branch_create(&reference, pointer, namePointer, commit.pointer, force ? 1 : 0),
                context: "git_branch_create"
            )
        }

        guard let reference else {
            throw makeMissingPointerError(function: "git_branch_create")
        }

        return Branch(repository: self, reference: Reference(pointer: reference), type: .local)
    }

    @discardableResult
    public func createBranch(
        named name: String,
        from revision: String,
        force: Bool = false
    ) throws -> Branch {
        try createBranch(named: name, at: commit(revision), force: force)
    }

    public func renameBranch(
        _ branch: Branch,
        to newName: String,
        force: Bool = false
    ) throws -> Branch {
        var reference: OpaquePointer?

        _ = try newName.withCString { newNamePointer in
            try check(
                git_branch_move(&reference, branch.reference.pointer, newNamePointer, force ? 1 : 0),
                context: "git_branch_move"
            )
        }

        guard let reference else {
            throw makeMissingPointerError(function: "git_branch_move")
        }

        return Branch(repository: self, reference: Reference(pointer: reference), type: .local)
    }

    public func deleteBranch(_ branch: Branch) throws {
        try check(git_branch_delete(branch.reference.pointer), context: "git_branch_delete")
    }
}
