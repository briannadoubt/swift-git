import Foundation
import Libgit2Bindings

public struct CheckoutStrategy: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let safe: CheckoutStrategy = []
    public static let force = CheckoutStrategy(rawValue: 1 << 1)
    public static let recreateMissing = CheckoutStrategy(rawValue: 1 << 2)
    public static let allowConflicts = CheckoutStrategy(rawValue: 1 << 4)
    public static let removeUntracked = CheckoutStrategy(rawValue: 1 << 5)
    public static let removeIgnored = CheckoutStrategy(rawValue: 1 << 6)
    public static let updateOnly = CheckoutStrategy(rawValue: 1 << 7)
    public static let skipUnmerged = CheckoutStrategy(rawValue: 1 << 10)
    public static let useOurs = CheckoutStrategy(rawValue: 1 << 11)
    public static let useTheirs = CheckoutStrategy(rawValue: 1 << 12)
    public static let dontOverwriteIgnored = CheckoutStrategy(rawValue: 1 << 19)
    public static let dontRemoveExisting = CheckoutStrategy(rawValue: 1 << 22)
    public static let dryRun = CheckoutStrategy(rawValue: 1 << 24)
    public static let none = CheckoutStrategy(rawValue: 1 << 30)

    public var description: String {
        if rawValue == 0 {
            return "safe"
        }

        let labels: [(CheckoutStrategy, String)] = [
            (.force, "force"),
            (.recreateMissing, "recreate-missing"),
            (.allowConflicts, "allow-conflicts"),
            (.removeUntracked, "remove-untracked"),
            (.removeIgnored, "remove-ignored"),
            (.updateOnly, "update-only"),
            (.skipUnmerged, "skip-unmerged"),
            (.useOurs, "use-ours"),
            (.useTheirs, "use-theirs"),
            (.dontOverwriteIgnored, "dont-overwrite-ignored"),
            (.dontRemoveExisting, "dont-remove-existing"),
            (.dryRun, "dry-run"),
            (.none, "none")
        ]

        return labels.compactMap { contains($0.0) ? $0.1 : nil }.joined(separator: ", ")
    }
}

extension Repository {
    public func setHEAD(to referenceName: String) throws {
        _ = try referenceName.withCString { referenceNamePointer in
            try check(git_repository_set_head(pointer, referenceNamePointer), context: "git_repository_set_head")
        }
    }

    public func detachHEAD(at oid: OID) throws {
        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(git_repository_set_head_detached(pointer, oidPointer), context: "git_repository_set_head_detached")
        }
    }

    public func detachHEAD() throws {
        try check(git_repository_detach_head(pointer), context: "git_repository_detach_head")
    }

    public func checkoutHEAD(strategy: CheckoutStrategy = .safe) throws {
        var options = try checkoutOptions(strategy: strategy)
        try check(git_checkout_head(pointer, &options), context: "git_checkout_head")
    }

    public func checkout(revision: String, strategy: CheckoutStrategy = .safe) throws {
        let object = try objectPointer(for: revision)
        defer { git_object_free(object) }

        var options = try checkoutOptions(strategy: strategy)
        try check(git_checkout_tree(pointer, object, &options), context: "git_checkout_tree")

        do {
            let commit = try commit(revision)
            try detachHEAD(at: commit.id)
        } catch let error as GitError
            where error.knownCode == .invalidSpec || error.knownCode == .peel || error.knownCode == .notFound {
        }
    }

    public func checkout(branch named: String, strategy: CheckoutStrategy = .safe) throws {
        let referenceName = named.hasPrefix("refs/") ? named : "refs/heads/\(named)"
        try setHEAD(to: referenceName)
        try checkoutHEAD(strategy: strategy)
    }

    private func checkoutOptions(strategy: CheckoutStrategy) throws -> git_checkout_options {
        var options = git_checkout_options()
        try check(
            git_checkout_options_init(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION)),
            context: "git_checkout_options_init"
        )

        options.checkout_strategy = strategy.rawValue
        return options
    }
}
