import Foundation
import Libgit2Bindings

public final class Reference {
    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_reference_free(pointer)
    }

    public var name: String {
        gitString(git_reference_name(pointer)) ?? ""
    }

    public var shorthand: String {
        gitString(git_reference_shorthand(pointer)) ?? name
    }

    public var symbolicTarget: String? {
        gitString(git_reference_symbolic_target(pointer))
    }

    public var target: OID? {
        git_reference_target(pointer).map { OID($0.pointee) }
    }

    public var peeledTarget: OID? {
        git_reference_target_peel(pointer).map { OID($0.pointee) }
    }

    public var isBranch: Bool {
        git_reference_is_branch(pointer) > 0
    }

    public var isRemote: Bool {
        git_reference_is_remote(pointer) > 0
    }

    public var isTag: Bool {
        git_reference_is_tag(pointer) > 0
    }

    public func resolved() throws -> Reference {
        var resolved: OpaquePointer?
        try check(git_reference_resolve(&resolved, pointer), context: "git_reference_resolve")

        guard let resolved else {
            throw makeMissingPointerError(function: "git_reference_resolve")
        }

        return Reference(pointer: resolved)
    }
}
