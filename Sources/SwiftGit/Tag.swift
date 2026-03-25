import Foundation
import Libgit2Bindings

public struct TagReference: Hashable, Sendable {
    public let name: String
    public let referenceName: String
    public let targetID: OID
    public let targetType: ObjectType?
    public let annotationID: OID?
    public let tagger: Signature?
    public let message: String?

    public var isAnnotated: Bool {
        annotationID != nil
    }
}

extension Repository {
    public func tag(named name: String) throws -> TagReference {
        let referenceName = name.hasPrefix("refs/tags/") ? name : "refs/tags/\(name)"
        let shortName: String

        if referenceName.hasPrefix("refs/tags/") {
            shortName = String(referenceName.dropFirst("refs/tags/".count))
        } else {
            shortName = referenceName
        }

        var oid = git_oid()
        _ = try referenceName.withCString { referenceNamePointer in
            try check(
                git_reference_name_to_id(&oid, pointer, referenceNamePointer),
                context: "git_reference_name_to_id"
            )
        }

        let tagOID = OID(oid)
        let object = try objectPointer(for: tagOID, type: .any)
        defer { git_object_free(object) }

        let objectType = ObjectType(gitObjectType: git_object_type(object))
        if objectType == .tag {
            var tag: OpaquePointer?
            _ = try tagOID.withUnsafeGitOID { oidPointer in
                try check(git_tag_lookup(&tag, pointer, oidPointer), context: "git_tag_lookup")
            }

            guard let tag else {
                throw makeMissingPointerError(function: "git_tag_lookup")
            }

            defer { git_tag_free(tag) }
            return TagReference(
                name: gitString(git_tag_name(tag)) ?? shortName,
                referenceName: referenceName,
                targetID: OID(git_tag_target_id(tag).pointee),
                targetType: ObjectType(gitObjectType: git_tag_target_type(tag)),
                annotationID: OID(git_tag_id(tag).pointee),
                tagger: git_tag_tagger(tag).map(Signature.init),
                message: gitString(git_tag_message(tag))
            )
        }

        return TagReference(
            name: shortName,
            referenceName: referenceName,
            targetID: tagOID,
            targetType: objectType,
            annotationID: nil,
            tagger: nil,
            message: nil
        )
    }

    public func tagNames(matching pattern: String? = nil) throws -> [String] {
        var names = git_strarray()

        if let pattern {
            _ = try pattern.withCString { patternPointer in
                try check(git_tag_list_match(&names, patternPointer, pointer), context: "git_tag_list_match")
            }
        } else {
            try check(git_tag_list(&names, pointer), context: "git_tag_list")
        }

        defer { git_strarray_dispose(&names) }
        return strings(from: names)
    }

    public func tags(matching pattern: String? = nil) throws -> [TagReference] {
        try tagNames(matching: pattern).map(tag(named:))
    }

    @discardableResult
    public func createLightweightTag(
        named name: String,
        target revision: String = "HEAD",
        force: Bool = false
    ) throws -> TagReference {
        let object = try objectPointer(for: revision)
        defer { git_object_free(object) }

        var oid = git_oid()
        _ = try name.withCString { namePointer in
            try check(
                git_tag_create_lightweight(&oid, pointer, namePointer, object, force ? 1 : 0),
                context: "git_tag_create_lightweight"
            )
        }

        return try tag(named: name)
    }

    @discardableResult
    public func createAnnotatedTag(
        named name: String,
        target revision: String = "HEAD",
        message: String,
        tagger: Signature,
        force: Bool = false
    ) throws -> TagReference {
        let object = try objectPointer(for: revision)
        defer { git_object_free(object) }

        var oid = git_oid()
        _ = try tagger.withGitSignature { taggerPointer in
            try name.withCString { namePointer in
                try message.withCString { messagePointer in
                    try check(
                        git_tag_create(
                            &oid,
                            pointer,
                            namePointer,
                            object,
                            taggerPointer,
                            messagePointer,
                            force ? 1 : 0
                        ),
                        context: "git_tag_create"
                    )
                }
            }
        }

        return try tag(named: name)
    }

    public func deleteTag(named name: String) throws {
        _ = try name.withCString { namePointer in
            try check(git_tag_delete(pointer, namePointer), context: "git_tag_delete")
        }
    }
}
