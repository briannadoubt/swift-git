import Foundation
import Libgit2Bindings

public struct Signature: Hashable, CustomStringConvertible, Sendable {
    public let name: String
    public let email: String
    public let date: Date
    public let timeZoneOffsetMinutes: Int

    public init(
        name: String,
        email: String,
        date: Date = .init(),
        timeZoneOffsetMinutes: Int? = nil
    ) {
        self.name = name
        self.email = email
        self.date = date
        self.timeZoneOffsetMinutes = timeZoneOffsetMinutes ?? TimeZone.current.secondsFromGMT(for: date) / 60
    }

    public var description: String {
        "\(name) <\(email)>"
    }

    internal init(_ pointer: UnsafePointer<git_signature>) {
        let signature = pointer.pointee
        self.name = gitString(signature.name) ?? ""
        self.email = gitString(signature.email) ?? ""
        self.date = Date(timeIntervalSince1970: TimeInterval(signature.when.time))
        self.timeZoneOffsetMinutes = Int(signature.when.offset)
    }

    internal func withGitSignature<T>(
        _ body: (UnsafePointer<git_signature>) throws -> T
    ) throws -> T {
        var pointer: UnsafeMutablePointer<git_signature>?

        _ = try name.withCString { namePointer in
            try email.withCString { emailPointer in
                try check(
                    git_signature_new(
                        &pointer,
                        namePointer,
                        emailPointer,
                        Int64(date.timeIntervalSince1970),
                        Int32(timeZoneOffsetMinutes)
                    ),
                    context: "git_signature_new"
                )
            }
        }

        guard let pointer else {
            throw makeMissingPointerError(function: "git_signature_new")
        }

        defer { git_signature_free(pointer) }
        return try body(UnsafePointer(pointer))
    }
}
