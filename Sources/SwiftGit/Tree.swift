import Foundation
import Libgit2Bindings

public struct TreeEntry: Hashable, Sendable {
    public let name: String
    public let oid: OID
    public let objectType: ObjectType?
    public let fileMode: UInt16

    internal init(pointer: OpaquePointer) {
        self.name = gitString(git_tree_entry_name(pointer)) ?? ""
        self.oid = OID(git_tree_entry_id(pointer).pointee)
        self.objectType = ObjectType(gitObjectType: git_tree_entry_type(pointer))
        self.fileMode = UInt16(truncatingIfNeeded: rawUInt32(of: git_tree_entry_filemode(pointer)))
    }
}

public final class Tree {
    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_tree_free(pointer)
    }

    public var id: OID {
        OID(git_tree_id(pointer).pointee)
    }

    public var entryCount: Int {
        Int(git_tree_entrycount(pointer))
    }

    public func entries() -> [TreeEntry] {
        (0..<entryCount).compactMap(entry(at:))
    }

    public func entry(at index: Int) -> TreeEntry? {
        guard let entry = git_tree_entry_byindex(pointer, index) else {
            return nil
        }

        return TreeEntry(pointer: entry)
    }

    public func entry(named name: String) -> TreeEntry? {
        name.withCString { namePointer in
            guard let entry = git_tree_entry_byname(pointer, namePointer) else {
                return nil
            }

            return TreeEntry(pointer: entry)
        }
    }

    public func entry(atPath path: String) throws -> TreeEntry {
        var entry: OpaquePointer?

        _ = try path.withCString { pathPointer in
            try check(git_tree_entry_bypath(&entry, pointer, pathPointer), context: "git_tree_entry_bypath")
        }

        guard let entry else {
            throw makeMissingPointerError(function: "git_tree_entry_bypath")
        }

        defer { git_tree_entry_free(entry) }
        return TreeEntry(pointer: entry)
    }
}
