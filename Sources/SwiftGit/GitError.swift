import Foundation
import Libgit2Bindings

public enum GitErrorCode: Int32, CustomStringConvertible, Sendable {
    case generic = -1
    case notFound = -3
    case exists = -4
    case ambiguous = -5
    case bufferTooShort = -6
    case user = -7
    case bareRepository = -8
    case unbornBranch = -9
    case unmerged = -10
    case nonFastForward = -11
    case invalidSpec = -12
    case conflict = -13
    case locked = -14
    case modified = -15
    case authentication = -16
    case certificate = -17
    case applied = -18
    case peel = -19
    case endOfFile = -20
    case invalid = -21
    case uncommitted = -22
    case directory = -23
    case mergeConflict = -24
    case passthrough = -30
    case iterationOver = -31
    case mismatch = -33
    case indexDirty = -34
    case applyFailed = -35
    case ownership = -36
    case timeout = -37
    case unchanged = -38
    case notSupported = -39
    case readOnly = -40

    public var description: String {
        switch self {
        case .generic: return "generic failure"
        case .notFound: return "not found"
        case .exists: return "already exists"
        case .ambiguous: return "ambiguous"
        case .bufferTooShort: return "buffer too short"
        case .user: return "user callback failure"
        case .bareRepository: return "bare repository"
        case .unbornBranch: return "unborn branch"
        case .unmerged: return "unmerged"
        case .nonFastForward: return "non fast-forward"
        case .invalidSpec: return "invalid spec"
        case .conflict: return "conflict"
        case .locked: return "locked"
        case .modified: return "modified"
        case .authentication: return "authentication failed"
        case .certificate: return "certificate error"
        case .applied: return "already applied"
        case .peel: return "cannot peel"
        case .endOfFile: return "unexpected EOF"
        case .invalid: return "invalid input"
        case .uncommitted: return "uncommitted changes"
        case .directory: return "directory error"
        case .mergeConflict: return "merge conflict"
        case .passthrough: return "callback passthrough"
        case .iterationOver: return "iteration complete"
        case .mismatch: return "hash mismatch"
        case .indexDirty: return "index dirty"
        case .applyFailed: return "apply failed"
        case .ownership: return "ownership error"
        case .timeout: return "timeout"
        case .unchanged: return "unchanged"
        case .notSupported: return "not supported"
        case .readOnly: return "read-only"
        }
    }
}

public enum GitErrorCategory: Int32, CustomStringConvertible, Sendable {
    case none = 0
    case noMemory
    case os
    case invalid
    case reference
    case zlib
    case repository
    case config
    case regex
    case odb
    case index
    case object
    case net
    case tag
    case tree
    case indexer
    case ssl
    case submodule
    case thread
    case stash
    case checkout
    case fetchHead
    case merge
    case ssh
    case filter
    case revert
    case callback
    case cherryPick
    case describe
    case rebase
    case filesystem
    case patch
    case worktree
    case sha
    case http
    case internalError
    case grafts

    public var description: String {
        switch self {
        case .none: return "none"
        case .noMemory: return "no memory"
        case .os: return "os"
        case .invalid: return "invalid"
        case .reference: return "reference"
        case .zlib: return "zlib"
        case .repository: return "repository"
        case .config: return "config"
        case .regex: return "regex"
        case .odb: return "object database"
        case .index: return "index"
        case .object: return "object"
        case .net: return "network"
        case .tag: return "tag"
        case .tree: return "tree"
        case .indexer: return "indexer"
        case .ssl: return "ssl"
        case .submodule: return "submodule"
        case .thread: return "thread"
        case .stash: return "stash"
        case .checkout: return "checkout"
        case .fetchHead: return "fetch head"
        case .merge: return "merge"
        case .ssh: return "ssh"
        case .filter: return "filter"
        case .revert: return "revert"
        case .callback: return "callback"
        case .cherryPick: return "cherry-pick"
        case .describe: return "describe"
        case .rebase: return "rebase"
        case .filesystem: return "filesystem"
        case .patch: return "patch"
        case .worktree: return "worktree"
        case .sha: return "sha"
        case .http: return "http"
        case .internalError: return "internal"
        case .grafts: return "grafts"
        }
    }
}

public struct GitError: Error, CustomStringConvertible, Sendable {
    public let code: Int32
    public let category: GitErrorCategory
    public let message: String
    public let context: String?

    public var knownCode: GitErrorCode? {
        GitErrorCode(rawValue: code)
    }

    public var description: String {
        let codeDescription = knownCode?.description ?? "error \(code)"

        guard let context else {
            return "\(message) [\(category.description), \(codeDescription)]"
        }

        return "\(context): \(message) [\(category.description), \(codeDescription)]"
    }

    internal static func lastError(code: Int32, context: String? = nil) -> GitError {
        let lastError = git_error_last()
        let message = gitString(lastError?.pointee.message) ?? "libgit2 error \(code)"
        let category = GitErrorCategory(rawValue: Int32(lastError?.pointee.klass ?? 0)) ?? .none

        return GitError(
            code: code,
            category: category,
            message: message,
            context: context
        )
    }
}
