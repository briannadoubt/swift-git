import Foundation
import Libgit2Bindings

public struct CloneOptions: Hashable, Sendable {
    public var bare: Bool
    public var checkoutBranch: String?

    public init(bare: Bool = false, checkoutBranch: String? = nil) {
        self.bare = bare
        self.checkoutBranch = checkoutBranch
    }

    public static let `default` = CloneOptions()
}

public final class Repository {
    public enum State: Int32, CustomStringConvertible {
        case none = 0
        case merge
        case revert
        case revertSequence
        case cherryPick
        case cherryPickSequence
        case bisect
        case rebase
        case rebaseInteractive
        case rebaseMerge
        case applyMailbox
        case applyMailboxOrRebase

        public var description: String {
            switch self {
            case .none: return "none"
            case .merge: return "merge"
            case .revert: return "revert"
            case .revertSequence: return "revert sequence"
            case .cherryPick: return "cherry-pick"
            case .cherryPickSequence: return "cherry-pick sequence"
            case .bisect: return "bisect"
            case .rebase: return "rebase"
            case .rebaseInteractive: return "rebase interactive"
            case .rebaseMerge: return "rebase merge"
            case .applyMailbox: return "apply mailbox"
            case .applyMailboxOrRebase: return "apply mailbox or rebase"
            }
        }
    }

    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_repository_free(pointer)
    }

    public static func open(at path: String) throws -> Repository {
        try LibGit2Runtime.ensureInitialized()

        var repository: OpaquePointer?
        _ = try path.withCString { pathPointer in
            try check(git_repository_open(&repository, pathPointer), context: "git_repository_open")
        }

        guard let repository else {
            throw makeMissingPointerError(function: "git_repository_open")
        }

        return Repository(pointer: repository)
    }

    public static func open(at url: URL) throws -> Repository {
        try open(at: url.path)
    }

    public static func create(
        at path: String,
        bare: Bool = false,
        initialBranch: String? = nil
    ) throws -> Repository {
        try LibGit2Runtime.ensureInitialized()

        var repository: OpaquePointer?
        var options = git_repository_init_options()
        try check(
            git_repository_init_options_init(&options, UInt32(GIT_REPOSITORY_INIT_OPTIONS_VERSION)),
            context: "git_repository_init_options_init"
        )

        options.flags = rawUInt32(of: GIT_REPOSITORY_INIT_MKPATH)
        if bare {
            options.flags |= rawUInt32(of: GIT_REPOSITORY_INIT_BARE)
        }

        _ = try withOptionalCString(initialBranch) { branchPointer in
            options.initial_head = branchPointer

            _ = try path.withCString { pathPointer in
                try check(
                    git_repository_init_ext(&repository, pathPointer, &options),
                    context: "git_repository_init_ext"
                )
            }
        }

        guard let repository else {
            throw makeMissingPointerError(function: "git_repository_init_ext")
        }

        return Repository(pointer: repository)
    }

    public static func create(
        at url: URL,
        bare: Bool = false,
        initialBranch: String? = nil
    ) throws -> Repository {
        try create(at: url.path, bare: bare, initialBranch: initialBranch)
    }

    public static func clone(
        from source: String,
        to destination: String,
        options: CloneOptions = .default
    ) throws -> Repository {
        try LibGit2Runtime.ensureInitialized()

        var repository: OpaquePointer?
        var cloneOptions = git_clone_options()
        try check(
            git_clone_options_init(&cloneOptions, UInt32(GIT_CLONE_OPTIONS_VERSION)),
            context: "git_clone_options_init"
        )

        cloneOptions.bare = options.bare ? 1 : 0

        _ = try withOptionalCString(options.checkoutBranch) { branchPointer in
            cloneOptions.checkout_branch = branchPointer

            _ = try source.withCString { sourcePointer in
                try destination.withCString { destinationPointer in
                    try check(
                        git_clone(&repository, sourcePointer, destinationPointer, &cloneOptions),
                        context: "git_clone"
                    )
                }
            }
        }

        guard let repository else {
            throw makeMissingPointerError(function: "git_clone")
        }

        return Repository(pointer: repository)
    }

    public static func discover(
        startingAt path: String,
        acrossFilesystems: Bool = true,
        ceilingDirectories: [String] = []
    ) throws -> String {
        try LibGit2Runtime.ensureInitialized()

        let ceilingPaths = ceilingDirectories.joined(separator: ":")
        var buffer = git_buf()
        defer { git_buf_dispose(&buffer) }

        _ = try path.withCString { pathPointer in
            try withOptionalCString(ceilingPaths.isEmpty ? nil : ceilingPaths) { ceilingPointer in
                try check(
                    git_repository_discover(
                        &buffer,
                        pathPointer,
                        acrossFilesystems ? 1 : 0,
                        ceilingPointer
                    ),
                    context: "git_repository_discover"
                )
            }
        }

        return bufferString(buffer)
    }

    public var gitDirectoryPath: String {
        gitString(git_repository_path(pointer)) ?? ""
    }

    public var gitDirectoryURL: URL {
        makeFileURL(path: gitDirectoryPath, isDirectory: true)!
    }

    public var workingDirectoryPath: String? {
        gitString(git_repository_workdir(pointer))
    }

    public var workingDirectoryURL: URL? {
        makeFileURL(path: workingDirectoryPath, isDirectory: true)
    }

    public var isBare: Bool {
        git_repository_is_bare(pointer) > 0
    }

    public var isHEADDetached: Bool {
        get throws {
            try check(git_repository_head_detached(pointer), context: "git_repository_head_detached") > 0
        }
    }

    public var isHEADUnborn: Bool {
        get throws {
            try check(git_repository_head_unborn(pointer), context: "git_repository_head_unborn") > 0
        }
    }

    public var state: State {
        State(rawValue: git_repository_state(pointer)) ?? .none
    }

    public var namespace: String? {
        gitString(git_repository_get_namespace(pointer))
    }

    public func setNamespace(_ namespace: String?) throws {
        _ = try withOptionalCString(namespace) { namespacePointer in
            try check(git_repository_set_namespace(pointer, namespacePointer), context: "git_repository_set_namespace")
        }
    }

    public func headReference() throws -> Reference {
        var reference: OpaquePointer?
        try check(git_repository_head(&reference, pointer), context: "git_repository_head")

        guard let reference else {
            throw makeMissingPointerError(function: "git_repository_head")
        }

        return Reference(pointer: reference)
    }

    public func headCommit() throws -> Commit {
        var oid = git_oid()
        try check(
            git_reference_name_to_id(&oid, pointer, "HEAD"),
            context: "git_reference_name_to_id"
        )

        return try commit(OID(oid))
    }

    public func reference(named name: String) throws -> Reference {
        var reference: OpaquePointer?
        _ = try name.withCString { namePointer in
            try check(git_reference_lookup(&reference, pointer, namePointer), context: "git_reference_lookup")
        }

        guard let reference else {
            throw makeMissingPointerError(function: "git_reference_lookup")
        }

        return Reference(pointer: reference)
    }

    public func references(matching glob: String? = nil) throws -> [Reference] {
        let iterator = try referenceIterator(matching: glob)
        defer { git_reference_iterator_free(iterator) }

        let iterationOver = GitErrorCode.iterationOver.rawValue
        var references: [Reference] = []

        while true {
            var reference: OpaquePointer?
            let result = git_reference_next(&reference, iterator)

            if result == iterationOver {
                break
            }

            try check(result, context: "git_reference_next")

            if let reference {
                references.append(Reference(pointer: reference))
            }
        }

        return references
    }

    public func commit(_ oid: OID) throws -> Commit {
        var commit: OpaquePointer?

        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(git_commit_lookup(&commit, pointer, oidPointer), context: "git_commit_lookup")
        }

        guard let commit else {
            throw makeMissingPointerError(function: "git_commit_lookup")
        }

        return Commit(pointer: commit)
    }

    public func commit(_ revision: String) throws -> Commit {
        var object: OpaquePointer?

        _ = try revision.withCString { revisionPointer in
            try check(git_revparse_single(&object, pointer, revisionPointer), context: "git_revparse_single")
        }

        guard let object else {
            throw makeMissingPointerError(function: "git_revparse_single")
        }

        defer { git_object_free(object) }

        var peeled: OpaquePointer?
        try check(git_object_peel(&peeled, object, GIT_OBJECT_COMMIT), context: "git_object_peel")

        guard let peeled else {
            throw makeMissingPointerError(function: "git_object_peel")
        }

        return Commit(pointer: peeled)
    }

    public func tree(_ oid: OID) throws -> Tree {
        var tree: OpaquePointer?

        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(git_tree_lookup(&tree, pointer, oidPointer), context: "git_tree_lookup")
        }

        guard let tree else {
            throw makeMissingPointerError(function: "git_tree_lookup")
        }

        return Tree(pointer: tree)
    }

    public func blob(_ oid: OID) throws -> Blob {
        var blob: OpaquePointer?

        _ = try oid.withUnsafeGitOID { oidPointer in
            try check(git_blob_lookup(&blob, pointer, oidPointer), context: "git_blob_lookup")
        }

        guard let blob else {
            throw makeMissingPointerError(function: "git_blob_lookup")
        }

        return Blob(pointer: blob)
    }

    public func index() throws -> Index {
        var index: OpaquePointer?
        try check(git_repository_index(&index, pointer), context: "git_repository_index")

        guard let index else {
            throw makeMissingPointerError(function: "git_repository_index")
        }

        return Index(pointer: index)
    }

    public func defaultSignature() throws -> Signature {
        var signature: UnsafeMutablePointer<git_signature>?
        try check(git_signature_default(&signature, pointer), context: "git_signature_default")

        guard let signature else {
            throw makeMissingPointerError(function: "git_signature_default")
        }

        defer { git_signature_free(signature) }
        return Signature(UnsafePointer(signature))
    }

    public func writeBlob(_ data: Data) throws -> OID {
        var oid = git_oid()

        let result = data.withUnsafeBytes { bytes in
            git_blob_create_from_buffer(&oid, pointer, bytes.baseAddress, bytes.count)
        }

        try check(result, context: "git_blob_create_from_buffer")
        return OID(oid)
    }

    public func status(
        includeIgnored: Bool = false,
        recurseIgnoredDirectories: Bool = false
    ) throws -> [StatusEntry] {
        var options = git_status_options()
        try check(
            git_status_options_init(&options, UInt32(GIT_STATUS_OPTIONS_VERSION)),
            context: "git_status_options_init"
        )

        options.flags = 1 << 0
        options.flags |= 1 << 4

        if includeIgnored {
            options.flags |= 1 << 1
        }

        if recurseIgnoredDirectories {
            options.flags |= 1 << 6
        }

        var list: OpaquePointer?
        try check(git_status_list_new(&list, pointer, &options), context: "git_status_list_new")

        guard let list else {
            throw makeMissingPointerError(function: "git_status_list_new")
        }

        defer { git_status_list_free(list) }

        let count = Int(git_status_list_entrycount(list))
        return (0..<count).compactMap { index in
            guard let entry = git_status_byindex(list, index)?.pointee else {
                return nil
            }

            let headToIndex = entry.head_to_index.map { DiffDelta($0.pointee) }
            let indexToWorkdir = entry.index_to_workdir.map { DiffDelta($0.pointee) }
            let path =
                indexToWorkdir?.path ??
                headToIndex?.path ??
                ""

            return StatusEntry(
                path: path,
                status: Status(rawValue: rawUInt32(of: entry.status)),
                headToIndex: headToIndex,
                indexToWorkdir: indexToWorkdir
            )
        }
    }

    public func diff(
        between oldTree: Tree? = nil,
        and newTree: Tree? = nil,
        options: DiffOptions = .default
    ) throws -> Diff {
        var diff: OpaquePointer?
        _ = try options.withGitOptions { optionsPointer in
            try check(
                git_diff_tree_to_tree(&diff, pointer, oldTree?.pointer, newTree?.pointer, optionsPointer),
                context: "git_diff_tree_to_tree"
            )
        }

        guard let diff else {
            throw makeMissingPointerError(function: "git_diff_tree_to_tree")
        }

        return Diff(pointer: diff)
    }

    public func diffTreeToIndex(
        from tree: Tree? = nil,
        index: Index? = nil,
        options: DiffOptions = .default
    ) throws -> Diff {
        var diff: OpaquePointer?
        _ = try options.withGitOptions { optionsPointer in
            try check(
                git_diff_tree_to_index(&diff, pointer, tree?.pointer, index?.pointer, optionsPointer),
                context: "git_diff_tree_to_index"
            )
        }

        guard let diff else {
            throw makeMissingPointerError(function: "git_diff_tree_to_index")
        }

        return Diff(pointer: diff)
    }

    public func diffIndexToWorkingDirectory(
        index: Index? = nil,
        options: DiffOptions = .default
    ) throws -> Diff {
        var diff: OpaquePointer?
        _ = try options.withGitOptions { optionsPointer in
            try check(
                git_diff_index_to_workdir(&diff, pointer, index?.pointer, optionsPointer),
                context: "git_diff_index_to_workdir"
            )
        }

        guard let diff else {
            throw makeMissingPointerError(function: "git_diff_index_to_workdir")
        }

        return Diff(pointer: diff)
    }

    public func diffToWorkingDirectory(
        from tree: Tree? = nil,
        options: DiffOptions = .default
    ) throws -> Diff {
        var diff: OpaquePointer?
        _ = try options.withGitOptions { optionsPointer in
            try check(
                git_diff_tree_to_workdir_with_index(&diff, pointer, tree?.pointer, optionsPointer),
                context: "git_diff_tree_to_workdir_with_index"
            )
        }

        guard let diff else {
            throw makeMissingPointerError(function: "git_diff_tree_to_workdir_with_index")
        }

        return Diff(pointer: diff)
    }

    @discardableResult
    public func commit(
        message: String,
        author: Signature,
        committer: Signature? = nil,
        updateReference: String? = "HEAD",
        parents explicitParents: [Commit]? = nil,
        messageEncoding: String? = nil
    ) throws -> Commit {
        let index = try self.index()
        try index.write()

        let treeOID = try index.writeTree()
        let tree = try self.tree(treeOID)
        let committer = committer ?? author
        let parents = try resolvedParents(explicitParents)

        var oid = git_oid()

        _ = try author.withGitSignature { authorPointer in
            try committer.withGitSignature { committerPointer in
                try withOptionalCString(updateReference) { updateReferencePointer in
                    try withOptionalCString(messageEncoding) { messageEncodingPointer in
                        try message.withCString { messagePointer in
                            var parentPointers = parents.map { Optional($0.pointer) }

                            let result = parentPointers.withUnsafeMutableBufferPointer { parentPointerBuffer in
                                git_commit_create(
                                    &oid,
                                    pointer,
                                    updateReferencePointer,
                                    authorPointer,
                                    committerPointer,
                                    messageEncodingPointer,
                                    messagePointer,
                                    tree.pointer,
                                    parentPointerBuffer.count,
                                    parentPointerBuffer.baseAddress
                                )
                            }

                            try check(result, context: "git_commit_create")
                        }
                    }
                }
            }
        }

        return try commit(OID(oid))
    }

    public func mergeBase(between first: OID, and second: OID) throws -> OID {
        var oid = git_oid()

        _ = try first.withUnsafeGitOID { firstPointer in
            try second.withUnsafeGitOID { secondPointer in
                try check(
                    git_merge_base(&oid, pointer, firstPointer, secondPointer),
                    context: "git_merge_base"
                )
            }
        }

        return OID(oid)
    }

    private func referenceIterator(matching glob: String?) throws -> OpaquePointer {
        var iterator: OpaquePointer?

        if let glob {
            _ = try glob.withCString { globPointer in
                try check(
                    git_reference_iterator_glob_new(&iterator, pointer, globPointer),
                    context: "git_reference_iterator_glob_new"
                )
            }
        } else {
            try check(git_reference_iterator_new(&iterator, pointer), context: "git_reference_iterator_new")
        }

        guard let iterator else {
            throw makeMissingPointerError(function: glob == nil ? "git_reference_iterator_new" : "git_reference_iterator_glob_new")
        }

        return iterator
    }

    private func resolvedParents(_ explicitParents: [Commit]?) throws -> [Commit] {
        if let explicitParents {
            return explicitParents
        }

        do {
            return [try headCommit()]
        } catch let error as GitError where error.knownCode == .unbornBranch || error.knownCode == .notFound {
            return []
        }
    }
}
