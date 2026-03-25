import Foundation
import Libgit2Bindings

public struct OID: LosslessStringConvertible, CustomStringConvertible, Hashable, Sendable {
    internal var rawValue: git_oid

    internal init(_ rawValue: git_oid) {
        self.rawValue = rawValue
    }

    public init?(_ description: String) {
        try? self.init(validating: description)
    }

    public init(validating hex: String) throws {
        try LibGit2Runtime.ensureInitialized()

        var oid = git_oid()
        try check(
            hex.withCString { git_oid_fromstr(&oid, $0) },
            context: "git_oid_fromstr"
        )

        self.rawValue = oid
    }

    public var description: String {
        withUnsafePointer(to: rawValue) { pointer in
            guard let string = git_oid_tostr_s(pointer) else {
                return String(repeating: "0", count: 40)
            }

            return String(cString: string)
        }
    }

    public func prefix(_ length: Int) -> String {
        let clampedLength = max(0, min(length, 40))
        var buffer = Array<CChar>(repeating: 0, count: clampedLength + 1)

        return withUnsafePointer(to: rawValue) { pointer in
            buffer.withUnsafeMutableBufferPointer { buffer in
                _ = git_oid_tostr(buffer.baseAddress, buffer.count, pointer)
            }

            return String(decoding: buffer.dropLast(1).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }

    public static func == (lhs: OID, rhs: OID) -> Bool {
        lhs.description == rhs.description
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    internal func withUnsafeGitOID<T>(_ body: (UnsafePointer<git_oid>) throws -> T) rethrows -> T {
        try withUnsafePointer(to: rawValue, body)
    }
}
