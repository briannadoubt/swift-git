import Foundation
import Libgit2Bindings

public final class Remote {
    private let repository: Repository
    internal let pointer: OpaquePointer

    internal init(repository: Repository, pointer: OpaquePointer) {
        self.repository = repository
        self.pointer = pointer
    }

    deinit {
        git_remote_free(pointer)
    }

    public var name: String? {
        gitString(git_remote_name(pointer))
    }

    public var url: String? {
        gitString(git_remote_url(pointer))
    }

    public var pushURL: String? {
        gitString(git_remote_pushurl(pointer))
    }

    public var isConnected: Bool {
        git_remote_connected(pointer) > 0
    }

    public var fetchRefspecs: [String] {
        get throws {
            var array = git_strarray()
            try check(git_remote_get_fetch_refspecs(&array, pointer), context: "git_remote_get_fetch_refspecs")
            defer { git_strarray_dispose(&array) }
            return strings(from: array)
        }
    }

    public func disconnect() throws {
        try check(git_remote_disconnect(pointer), context: "git_remote_disconnect")
    }

    public func fetch(reflogMessage: String? = nil) throws {
        var options = git_fetch_options()
        try check(git_fetch_options_init(&options, UInt32(GIT_FETCH_OPTIONS_VERSION)), context: "git_fetch_options_init")

        _ = try withOptionalCString(reflogMessage) { reflogMessagePointer in
            try check(git_remote_fetch(pointer, nil, &options, reflogMessagePointer), context: "git_remote_fetch")
        }
    }
}

extension Repository {
    public func remote(named name: String) throws -> Remote {
        var remote: OpaquePointer?

        _ = try name.withCString { namePointer in
            try check(git_remote_lookup(&remote, pointer, namePointer), context: "git_remote_lookup")
        }

        guard let remote else {
            throw makeMissingPointerError(function: "git_remote_lookup")
        }

        return Remote(repository: self, pointer: remote)
    }

    public func remoteNames() throws -> [String] {
        var array = git_strarray()
        try check(git_remote_list(&array, pointer), context: "git_remote_list")
        defer { git_strarray_dispose(&array) }
        return strings(from: array)
    }

    public func remotes() throws -> [Remote] {
        try remoteNames().map(remote(named:))
    }

    @discardableResult
    public func createRemote(named name: String, url: String) throws -> Remote {
        var remote: OpaquePointer?

        _ = try name.withCString { namePointer in
            try url.withCString { urlPointer in
                try check(
                    git_remote_create(&remote, pointer, namePointer, urlPointer),
                    context: "git_remote_create"
                )
            }
        }

        guard let remote else {
            throw makeMissingPointerError(function: "git_remote_create")
        }

        return Remote(repository: self, pointer: remote)
    }

    public func deleteRemote(named name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_remote_delete(pointer, namePointer), context: "git_remote_delete")
        }
    }

    public func setRemoteURL(named name: String, url: String) throws {
        _ = try name.withCString { namePointer in
            try url.withCString { urlPointer in
                try check(git_remote_set_url(pointer, namePointer, urlPointer), context: "git_remote_set_url")
            }
        }
    }

    public func setRemotePushURL(named name: String, url: String) throws {
        _ = try name.withCString { namePointer in
            try url.withCString { urlPointer in
                try check(git_remote_set_pushurl(pointer, namePointer, urlPointer), context: "git_remote_set_pushurl")
            }
        }
    }
}
