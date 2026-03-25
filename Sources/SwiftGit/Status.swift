import Foundation
import Libgit2Bindings

public struct Status: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let current: Status = []
    public static let indexNew = Status(rawValue: 1 << 0)
    public static let indexModified = Status(rawValue: 1 << 1)
    public static let indexDeleted = Status(rawValue: 1 << 2)
    public static let indexRenamed = Status(rawValue: 1 << 3)
    public static let indexTypeChange = Status(rawValue: 1 << 4)
    public static let workTreeNew = Status(rawValue: 1 << 7)
    public static let workTreeModified = Status(rawValue: 1 << 8)
    public static let workTreeDeleted = Status(rawValue: 1 << 9)
    public static let workTreeTypeChange = Status(rawValue: 1 << 10)
    public static let workTreeRenamed = Status(rawValue: 1 << 11)
    public static let workTreeUnreadable = Status(rawValue: 1 << 12)
    public static let ignored = Status(rawValue: 1 << 14)
    public static let conflicted = Status(rawValue: 1 << 15)

    public var description: String {
        if rawValue == 0 {
            return "current"
        }

        let labels: [(Status, String)] = [
            (.indexNew, "index-new"),
            (.indexModified, "index-modified"),
            (.indexDeleted, "index-deleted"),
            (.indexRenamed, "index-renamed"),
            (.indexTypeChange, "index-typechange"),
            (.workTreeNew, "worktree-new"),
            (.workTreeModified, "worktree-modified"),
            (.workTreeDeleted, "worktree-deleted"),
            (.workTreeTypeChange, "worktree-typechange"),
            (.workTreeRenamed, "worktree-renamed"),
            (.workTreeUnreadable, "worktree-unreadable"),
            (.ignored, "ignored"),
            (.conflicted, "conflicted")
        ]

        return labels
            .compactMap { contains($0.0) ? $0.1 : nil }
            .joined(separator: ", ")
    }
}

public struct StatusEntry: Hashable, Sendable {
    public let path: String
    public let status: Status
    public let headToIndex: DiffDelta?
    public let indexToWorkdir: DiffDelta?
}
