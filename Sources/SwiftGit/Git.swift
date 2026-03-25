import Foundation
import Libgit2Bindings

public enum Git {
    public static var libgit2Version: String {
        "\(LIBGIT2_VERSION_MAJOR).\(LIBGIT2_VERSION_MINOR).\(LIBGIT2_VERSION_REVISION)"
    }

    public static func open(_ path: String) throws -> Repository {
        try Repository.open(at: path)
    }

    public static func open(_ url: URL) throws -> Repository {
        try Repository.open(at: url)
    }

    public static func createRepository(
        at path: String,
        bare: Bool = false,
        initialBranch: String? = nil
    ) throws -> Repository {
        try Repository.create(at: path, bare: bare, initialBranch: initialBranch)
    }

    public static func createRepository(
        at url: URL,
        bare: Bool = false,
        initialBranch: String? = nil
    ) throws -> Repository {
        try Repository.create(at: url, bare: bare, initialBranch: initialBranch)
    }

    public static func clone(
        _ source: String,
        to destination: String,
        options: CloneOptions = .default
    ) throws -> Repository {
        try Repository.clone(from: source, to: destination, options: options)
    }

    public static func clone(
        _ source: URL,
        to destination: URL,
        options: CloneOptions = .default
    ) throws -> Repository {
        try Repository.clone(from: source.path, to: destination.path, options: options)
    }

    public static func discoverRepository(
        startingAt path: String,
        acrossFilesystems: Bool = true,
        ceilingDirectories: [String] = []
    ) throws -> String {
        try Repository.discover(
            startingAt: path,
            acrossFilesystems: acrossFilesystems,
            ceilingDirectories: ceilingDirectories
        )
    }

    public static func defaultConfig() throws -> Config {
        try Config.openDefault()
    }
}

internal enum LibGit2Runtime {
    private static let initializationResult: Result<Void, GitError> = {
        do {
            try check(Int32(git_libgit2_init()), context: "git_libgit2_init")
            return .success(())
        } catch let error as GitError {
            return .failure(error)
        } catch {
            return .failure(
                GitError(
                    code: GitErrorCode.generic.rawValue,
                    category: .none,
                    message: String(describing: error),
                    context: "git_libgit2_init"
                )
            )
        }
    }()

    static func ensureInitialized() throws {
        try initializationResult.get()
    }
}
