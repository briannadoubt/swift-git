import Foundation
import Libgit2Bindings

public struct IndexEntry: Hashable, Sendable {
    public let path: String
    public let oid: OID
    public let fileMode: UInt32
    public let fileSize: UInt32
    public let stage: Int

    internal init(pointer: UnsafePointer<git_index_entry>) {
        let entry = pointer.pointee
        self.path = gitString(entry.path) ?? ""
        self.oid = OID(entry.id)
        self.fileMode = entry.mode
        self.fileSize = entry.file_size
        self.stage = Int(git_index_entry_stage(pointer))
    }
}

public final class Index {
    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_index_free(pointer)
    }

    public var path: String? {
        gitString(git_index_path(pointer))
    }

    public var entryCount: Int {
        Int(git_index_entrycount(pointer))
    }

    public func entries() -> [IndexEntry] {
        (0..<entryCount).compactMap(entry(at:))
    }

    public func entry(at index: Int) -> IndexEntry? {
        guard let entry = git_index_get_byindex(pointer, index) else {
            return nil
        }

        return IndexEntry(pointer: entry)
    }

    public func entry(for path: String, stage: Int = 0) -> IndexEntry? {
        path.withCString { pathPointer in
            git_index_get_bypath(pointer, pathPointer, Int32(stage)).map(IndexEntry.init(pointer:))
        }
    }

    public func add(path: String) throws {
        _ = try path.withCString { pathPointer in
            try check(git_index_add_bypath(pointer, pathPointer), context: "git_index_add_bypath")
        }
    }

    public func add(paths: [String]) throws {
        for path in paths {
            try add(path: path)
        }
    }

    public func remove(path: String) throws {
        _ = try path.withCString { pathPointer in
            try check(git_index_remove_bypath(pointer, pathPointer), context: "git_index_remove_bypath")
        }
    }

    public func write() throws {
        try check(git_index_write(pointer), context: "git_index_write")
    }

    public func writeTree() throws -> OID {
        var oid = git_oid()
        try check(git_index_write_tree(&oid, pointer), context: "git_index_write_tree")
        return OID(oid)
    }
}
