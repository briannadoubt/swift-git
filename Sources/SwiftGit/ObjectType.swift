import Libgit2Bindings

public enum ObjectType: Int32, CustomStringConvertible, Sendable {
    case any = -2
    case invalid = -1
    case commit = 1
    case tree = 2
    case blob = 3
    case tag = 4
    case offsetDelta = 6
    case referenceDelta = 7

    public var description: String {
        switch self {
        case .any: return "any"
        case .invalid: return "invalid"
        case .commit: return "commit"
        case .tree: return "tree"
        case .blob: return "blob"
        case .tag: return "tag"
        case .offsetDelta: return "offset delta"
        case .referenceDelta: return "reference delta"
        }
    }

    internal init?(gitObjectType: git_object_t) {
        self.init(rawValue: rawInt32(of: gitObjectType))
    }

    internal var gitObjectType: git_object_t {
        switch self {
        case .any:
            return GIT_OBJECT_ANY
        case .invalid:
            return GIT_OBJECT_INVALID
        case .commit:
            return GIT_OBJECT_COMMIT
        case .tree:
            return GIT_OBJECT_TREE
        case .blob:
            return GIT_OBJECT_BLOB
        case .tag:
            return GIT_OBJECT_TAG
        case .offsetDelta:
            return GIT_OBJECT_OFS_DELTA
        case .referenceDelta:
            return GIT_OBJECT_REF_DELTA
        }
    }
}
