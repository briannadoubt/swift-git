import Foundation
import Libgit2Bindings

public final class Blob {
    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_blob_free(pointer)
    }

    public var id: OID {
        OID(git_blob_id(pointer).pointee)
    }

    public var size: Int {
        Int(git_blob_rawsize(pointer))
    }

    public var isBinary: Bool {
        git_blob_is_binary(pointer) > 0
    }

    public var data: Data {
        copiedData(from: git_blob_rawcontent(pointer), count: size)
    }

    public func string(encoding: String.Encoding = .utf8) -> String? {
        String(data: data, encoding: encoding)
    }
}
