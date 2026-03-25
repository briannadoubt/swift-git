import Foundation
import Libgit2Bindings

public enum ConfigLevel: Int32, CustomStringConvertible, Sendable {
    case programData = 1
    case system = 2
    case xdg = 3
    case global = 4
    case local = 5
    case worktree = 6
    case app = 7
    case highest = -1

    public var description: String {
        switch self {
        case .programData: return "programdata"
        case .system: return "system"
        case .xdg: return "xdg"
        case .global: return "global"
        case .local: return "local"
        case .worktree: return "worktree"
        case .app: return "app"
        case .highest: return "highest"
        }
    }
}

public struct ConfigEntry: Hashable, Sendable {
    public let name: String
    public let value: String?
    public let backendType: String?
    public let originPath: String?
    public let includeDepth: UInt32
    public let level: ConfigLevel?
}

public final class Config {
    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_config_free(pointer)
    }

    public static func openDefault() throws -> Config {
        try LibGit2Runtime.ensureInitialized()

        var config: OpaquePointer?
        try check(git_config_open_default(&config), context: "git_config_open_default")

        guard let config else {
            throw makeMissingPointerError(function: "git_config_open_default")
        }

        return Config(pointer: config)
    }

    public func snapshot() throws -> Config {
        var snapshot: OpaquePointer?
        try check(git_config_snapshot(&snapshot, pointer), context: "git_config_snapshot")

        guard let snapshot else {
            throw makeMissingPointerError(function: "git_config_snapshot")
        }

        return Config(pointer: snapshot)
    }

    public func entry(named name: String) throws -> ConfigEntry {
        guard let entry = try entryIfPresent(named: name) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .config,
                message: "No config entry named \(name)",
                context: "git_config_get_entry"
            )
        }

        return entry
    }

    public func entryIfPresent(named name: String) throws -> ConfigEntry? {
        var entry: UnsafeMutablePointer<git_config_entry>?

        do {
            _ = try name.withCString { namePointer in
                try check(git_config_get_entry(&entry, pointer, namePointer), context: "git_config_get_entry")
            }
        } catch let error as GitError where error.knownCode == .notFound {
            return nil
        }

        guard let entry else {
            throw makeMissingPointerError(function: "git_config_get_entry")
        }

        defer { git_config_entry_free(entry) }
        return ConfigEntry(
            name: gitString(entry.pointee.name) ?? name,
            value: gitString(entry.pointee.value),
            backendType: gitString(entry.pointee.backend_type),
            originPath: gitString(entry.pointee.origin_path),
            includeDepth: entry.pointee.include_depth,
            level: ConfigLevel(rawValue: rawInt32(of: entry.pointee.level))
        )
    }

    public func string(_ name: String) throws -> String {
        guard let value = try stringIfPresent(name) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .config,
                message: "No config entry named \(name)",
                context: "git_config_get_string_buf"
            )
        }

        return value
    }

    public func stringIfPresent(_ name: String) throws -> String? {
        do {
            let (_, value) = try withGitBuffer { buffer in
                _ = try name.withCString { namePointer in
                    try check(git_config_get_string_buf(buffer, pointer, namePointer), context: "git_config_get_string_buf")
                }
            }

            return value
        } catch let error as GitError where error.knownCode == .notFound {
            return nil
        }
    }

    public func int32(_ name: String) throws -> Int32 {
        guard let value = try int32IfPresent(name) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .config,
                message: "No config entry named \(name)",
                context: "git_config_get_int32"
            )
        }

        return value
    }

    public func int32IfPresent(_ name: String) throws -> Int32? {
        var value: Int32 = 0

        do {
            _ = try name.withCString { namePointer in
                try check(git_config_get_int32(&value, pointer, namePointer), context: "git_config_get_int32")
            }

            return value
        } catch let error as GitError where error.knownCode == .notFound {
            return nil
        }
    }

    public func int64(_ name: String) throws -> Int64 {
        guard let value = try int64IfPresent(name) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .config,
                message: "No config entry named \(name)",
                context: "git_config_get_int64"
            )
        }

        return value
    }

    public func int64IfPresent(_ name: String) throws -> Int64? {
        var value: Int64 = 0

        do {
            _ = try name.withCString { namePointer in
                try check(git_config_get_int64(&value, pointer, namePointer), context: "git_config_get_int64")
            }

            return value
        } catch let error as GitError where error.knownCode == .notFound {
            return nil
        }
    }

    public func bool(_ name: String) throws -> Bool {
        guard let value = try boolIfPresent(name) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .config,
                message: "No config entry named \(name)",
                context: "git_config_get_bool"
            )
        }

        return value
    }

    public func boolIfPresent(_ name: String) throws -> Bool? {
        var value: Int32 = 0

        do {
            _ = try name.withCString { namePointer in
                try check(git_config_get_bool(&value, pointer, namePointer), context: "git_config_get_bool")
            }

            return value != 0
        } catch let error as GitError where error.knownCode == .notFound {
            return nil
        }
    }

    public func path(_ name: String) throws -> String {
        guard let value = try pathIfPresent(name) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .config,
                message: "No config entry named \(name)",
                context: "git_config_get_path"
            )
        }

        return value
    }

    public func pathIfPresent(_ name: String) throws -> String? {
        do {
            let (_, value) = try withGitBuffer { buffer in
                _ = try name.withCString { namePointer in
                    try check(git_config_get_path(buffer, pointer, namePointer), context: "git_config_get_path")
                }
            }

            return value
        } catch let error as GitError where error.knownCode == .notFound {
            return nil
        }
    }

    public func set(_ value: String, for name: String) throws {
        _ = try name.withCString { namePointer in
            try value.withCString { valuePointer in
                try check(git_config_set_string(pointer, namePointer, valuePointer), context: "git_config_set_string")
            }
        }
    }

    public func set(_ value: Int32, for name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_config_set_int32(pointer, namePointer, value), context: "git_config_set_int32")
        }
    }

    public func set(_ value: Int64, for name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_config_set_int64(pointer, namePointer, value), context: "git_config_set_int64")
        }
    }

    public func set(_ value: Bool, for name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_config_set_bool(pointer, namePointer, value ? 1 : 0), context: "git_config_set_bool")
        }
    }

    public func remove(_ name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_config_delete_entry(pointer, namePointer), context: "git_config_delete_entry")
        }
    }
}

extension Repository {
    public func config() throws -> Config {
        var config: OpaquePointer?
        try check(git_repository_config(&config, pointer), context: "git_repository_config")

        guard let config else {
            throw makeMissingPointerError(function: "git_repository_config")
        }

        return Config(pointer: config)
    }

    public func configSnapshot() throws -> Config {
        var config: OpaquePointer?
        try check(git_repository_config_snapshot(&config, pointer), context: "git_repository_config_snapshot")

        guard let config else {
            throw makeMissingPointerError(function: "git_repository_config_snapshot")
        }

        return Config(pointer: config)
    }
}
