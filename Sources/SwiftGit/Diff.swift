import Foundation
import Libgit2Bindings

public struct DiffOptions: Hashable, Sendable {
    public var contextLines: UInt32
    public var interhunkLines: UInt32
    public var includeIgnored: Bool
    public var recurseIgnoredDirectories: Bool
    public var includeUntracked: Bool
    public var recurseUntrackedDirectories: Bool
    public var includeUnmodified: Bool
    public var includeTypeChange: Bool
    public var includeTypeChangeTrees: Bool
    public var ignoreFilemode: Bool
    public var showUntrackedContent: Bool
    public var disablePathspecMatch: Bool
    public var pathspecs: [String]

    public init(
        contextLines: UInt32 = 3,
        interhunkLines: UInt32 = 0,
        includeIgnored: Bool = false,
        recurseIgnoredDirectories: Bool = false,
        includeUntracked: Bool = false,
        recurseUntrackedDirectories: Bool = false,
        includeUnmodified: Bool = false,
        includeTypeChange: Bool = true,
        includeTypeChangeTrees: Bool = false,
        ignoreFilemode: Bool = false,
        showUntrackedContent: Bool = false,
        disablePathspecMatch: Bool = false,
        pathspecs: [String] = []
    ) {
        self.contextLines = contextLines
        self.interhunkLines = interhunkLines
        self.includeIgnored = includeIgnored
        self.recurseIgnoredDirectories = recurseIgnoredDirectories
        self.includeUntracked = includeUntracked
        self.recurseUntrackedDirectories = recurseUntrackedDirectories
        self.includeUnmodified = includeUnmodified
        self.includeTypeChange = includeTypeChange
        self.includeTypeChangeTrees = includeTypeChangeTrees
        self.ignoreFilemode = ignoreFilemode
        self.showUntrackedContent = showUntrackedContent
        self.disablePathspecMatch = disablePathspecMatch
        self.pathspecs = pathspecs
    }

    public static let `default` = DiffOptions()

    internal func withGitOptions<T>(
        _ body: (UnsafePointer<git_diff_options>?) throws -> T
    ) throws -> T {
        var options = git_diff_options()
        try check(
            git_diff_options_init(&options, UInt32(GIT_DIFF_OPTIONS_VERSION)),
            context: "git_diff_options_init"
        )

        options.context_lines = contextLines
        options.interhunk_lines = interhunkLines

        var flags: UInt32 = 0

        if includeIgnored {
            flags |= rawUInt32(of: GIT_DIFF_INCLUDE_IGNORED)
        }
        if recurseIgnoredDirectories {
            flags |= rawUInt32(of: GIT_DIFF_RECURSE_IGNORED_DIRS)
        }
        if includeUntracked {
            flags |= rawUInt32(of: GIT_DIFF_INCLUDE_UNTRACKED)
        }
        if recurseUntrackedDirectories {
            flags |= rawUInt32(of: GIT_DIFF_RECURSE_UNTRACKED_DIRS)
        }
        if includeUnmodified {
            flags |= rawUInt32(of: GIT_DIFF_INCLUDE_UNMODIFIED)
        }
        if includeTypeChange {
            flags |= rawUInt32(of: GIT_DIFF_INCLUDE_TYPECHANGE)
        }
        if includeTypeChangeTrees {
            flags |= rawUInt32(of: GIT_DIFF_INCLUDE_TYPECHANGE_TREES)
        }
        if ignoreFilemode {
            flags |= rawUInt32(of: GIT_DIFF_IGNORE_FILEMODE)
        }
        if showUntrackedContent {
            flags |= rawUInt32(of: GIT_DIFF_SHOW_UNTRACKED_CONTENT)
        }
        if disablePathspecMatch {
            flags |= rawUInt32(of: GIT_DIFF_DISABLE_PATHSPEC_MATCH)
        }

        options.flags = flags

        if pathspecs.isEmpty {
            return try body(&options)
        }

        return try withGitStrArray(pathspecs) { pathspec in
            options.pathspec = pathspec
            return try body(&options)
        }
    }
}

public struct DiffFile: Hashable, Sendable {
    public let path: String?
    public let oid: OID
    public let size: Int
    public let flags: UInt32
    public let mode: UInt16

    internal init(_ file: git_diff_file) {
        self.path = gitString(file.path)
        self.oid = OID(file.id)
        self.size = Int(file.size)
        self.flags = file.flags
        self.mode = file.mode
    }
}

public enum DiffDeltaStatus: Int32, CustomStringConvertible, Sendable {
    case unmodified = 0
    case added = 1
    case deleted = 2
    case modified = 3
    case renamed = 4
    case copied = 5
    case ignored = 6
    case untracked = 7
    case typeChanged = 8
    case unreadable = 9
    case conflicted = 10

    internal init?(gitDelta: git_delta_t) {
        self.init(rawValue: rawInt32(of: gitDelta))
    }

    public var statusCharacter: Character {
        switch self {
        case .unmodified: return " "
        case .added: return "A"
        case .deleted: return "D"
        case .modified: return "M"
        case .renamed: return "R"
        case .copied: return "C"
        case .ignored: return "!"
        case .untracked: return "?"
        case .typeChanged: return "T"
        case .unreadable: return "X"
        case .conflicted: return "U"
        }
    }

    public var description: String {
        switch self {
        case .unmodified: return "unmodified"
        case .added: return "added"
        case .deleted: return "deleted"
        case .modified: return "modified"
        case .renamed: return "renamed"
        case .copied: return "copied"
        case .ignored: return "ignored"
        case .untracked: return "untracked"
        case .typeChanged: return "type changed"
        case .unreadable: return "unreadable"
        case .conflicted: return "conflicted"
        }
    }
}

public struct DiffDelta: Hashable, Sendable {
    public let kind: DiffDeltaStatus
    public let similarity: Int
    public let oldFile: DiffFile
    public let newFile: DiffFile

    public var status: Character {
        kind.statusCharacter
    }

    public var path: String? {
        newFile.path ?? oldFile.path
    }

    internal init(_ delta: git_diff_delta) {
        self.kind = DiffDeltaStatus(gitDelta: delta.status) ?? .unmodified
        self.similarity = Int(delta.similarity)
        self.oldFile = DiffFile(delta.old_file)
        self.newFile = DiffFile(delta.new_file)
    }
}

public enum DiffPatchLineOrigin: Character, Hashable, Sendable {
    case context = " "
    case addition = "+"
    case deletion = "-"
    case contextEOFNoNewline = "="
    case additionEOFNoNewline = ">"
    case deletionEOFNoNewline = "<"
    case fileHeader = "F"
    case hunkHeader = "H"
    case binary = "B"
}

public struct DiffPatchLine: Hashable, Sendable {
    public let origin: DiffPatchLineOrigin?
    public let oldLineNumber: Int?
    public let newLineNumber: Int?
    public let text: String
}

public struct DiffPatchHunk: Hashable, Sendable {
    public let header: String
    public let oldStart: Int
    public let oldLineCount: Int
    public let newStart: Int
    public let newLineCount: Int
    public let lines: [DiffPatchLine]
}

public struct DiffPatch: Hashable, Sendable {
    public let delta: DiffDelta
    public let text: String
    public let hunks: [DiffPatchHunk]
    public let contextLineCount: Int
    public let addedLineCount: Int
    public let removedLineCount: Int
    public let isBinary: Bool
}

public struct DiffPatchMetadata: Hashable, Sendable {
    public let index: Int
    public let delta: DiffDelta
    public let byteCount: Int
    public let contextLineCount: Int
    public let addedLineCount: Int
    public let removedLineCount: Int
}

public struct DiffStats: Hashable, Sendable {
    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int
    public let summary: String
}

public final class Diff {
    private final class PatchPrintAccumulator {
        private var chunks: [Data] = []
        private var byteCount = 0

        func append(_ buffer: UnsafeRawBufferPointer) {
            guard
                buffer.isEmpty == false,
                let baseAddress = buffer.baseAddress
            else {
                return
            }
            chunks.append(Data(bytes: baseAddress, count: buffer.count))
            byteCount += buffer.count
        }

        func string() -> String {
            var data = Data(capacity: byteCount)
            for chunk in chunks {
                data.append(chunk)
            }
            return String(decoding: data, as: UTF8.self)
        }
    }

    internal let pointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_diff_free(pointer)
    }

    public var deltaCount: Int {
        Int(git_diff_num_deltas(pointer))
    }

    public func deltas() -> [DiffDelta] {
        (0..<deltaCount).compactMap { index in
            git_diff_get_delta(pointer, index).map { DiffDelta($0.pointee) }
        }
    }

    public func patch() throws -> String {
        var buffer = git_buf()
        defer { git_buf_dispose(&buffer) }

        try check(git_diff_to_buf(&buffer, pointer, GIT_DIFF_FORMAT_PATCH), context: "git_diff_to_buf")
        return bufferString(buffer)
    }

    public func nameOnly() throws -> String {
        var buffer = git_buf()
        defer { git_buf_dispose(&buffer) }

        try check(git_diff_to_buf(&buffer, pointer, GIT_DIFF_FORMAT_NAME_ONLY), context: "git_diff_to_buf")
        return bufferString(buffer)
    }

    public func nameStatus() throws -> String {
        var buffer = git_buf()
        defer { git_buf_dispose(&buffer) }

        try check(git_diff_to_buf(&buffer, pointer, GIT_DIFF_FORMAT_NAME_STATUS), context: "git_diff_to_buf")
        return bufferString(buffer)
    }

    public func stats() throws -> DiffStats {
        var stats: OpaquePointer?
        try check(git_diff_get_stats(&stats, pointer), context: "git_diff_get_stats")

        guard let stats else {
            throw makeMissingPointerError(function: "git_diff_get_stats")
        }

        defer { git_diff_stats_free(stats) }

        var buffer = git_buf()
        defer { git_buf_dispose(&buffer) }

        try check(
            git_diff_stats_to_buf(&buffer, stats, GIT_DIFF_STATS_FULL, 80),
            context: "git_diff_stats_to_buf"
        )

        return DiffStats(
            filesChanged: Int(git_diff_stats_files_changed(stats)),
            insertions: Int(git_diff_stats_insertions(stats)),
            deletions: Int(git_diff_stats_deletions(stats)),
            summary: bufferString(buffer)
        )
    }

    public func findSimilar() throws {
        try check(git_diff_find_similar(pointer, nil), context: "git_diff_find_similar")
    }

    public func patches() throws -> [DiffPatch] {
        try (0..<deltaCount).map(patch(at:))
    }

    public func structuredPatches() throws -> [DiffPatch] {
        try (0..<deltaCount).map(structuredPatch(at:))
    }

    public func firstPatch(where predicate: (DiffDelta) -> Bool) throws -> DiffPatch? {
        guard let index = firstMatchingPatchIndex(where: predicate) else {
            return nil
        }
        return try patch(at: index)
    }

    public func firstPatchMetadata(where predicate: (DiffDelta) -> Bool) throws -> DiffPatchMetadata? {
        guard let index = firstMatchingPatchIndex(where: predicate) else {
            return nil
        }
        return try patchMetadata(at: index)
    }

    public func patch(at index: Int) throws -> DiffPatch {
        try makePatch(at: index, includeText: true)
    }

    public func structuredPatch(at index: Int) throws -> DiffPatch {
        try makePatch(at: index, includeText: false)
    }

    public func patchMetadata(at index: Int) throws -> DiffPatchMetadata {
        try withPatch(at: index) { patchPointer, delta in
            try patchMetrics(for: patchPointer, index: index, delta: delta)
        }
    }

    public func patchText(at index: Int) throws -> String {
        try withPatch(at: index) { patchPointer, delta in
            try streamedPatchText(for: patchPointer, delta: delta)
        }
    }

    private func makeHunks(from patchPointer: OpaquePointer) throws -> [DiffPatchHunk] {
        let hunkCount = Int(git_patch_num_hunks(patchPointer))

        return try (0..<hunkCount).map { hunkIndex in
            var hunkPointer: UnsafePointer<git_diff_hunk>?
            var linesInHunk: Int = 0

            try check(
                git_patch_get_hunk(
                    &hunkPointer,
                    &linesInHunk,
                    patchPointer,
                    hunkIndex
                ),
                context: "git_patch_get_hunk"
            )

            guard let hunkPointer else {
                throw makeMissingPointerError(function: "git_patch_get_hunk")
            }

            let hunk = hunkPointer.pointee
            let header = withUnsafeBytes(of: hunk.header) { bytes -> String in
                String(
                    decoding: bytes.prefix(Int(hunk.header_len)),
                    as: UTF8.self
                ).trimmingCharacters(in: .newlines)
            }

            let lines = try (0..<linesInHunk).map { lineIndex -> DiffPatchLine in
                var linePointer: UnsafePointer<git_diff_line>?
                try check(
                    git_patch_get_line_in_hunk(
                        &linePointer,
                        patchPointer,
                        hunkIndex,
                        lineIndex
                    ),
                    context: "git_patch_get_line_in_hunk"
                )

                guard let linePointer else {
                    throw makeMissingPointerError(function: "git_patch_get_line_in_hunk")
                }

                let line = linePointer.pointee
                let origin = DiffPatchLineOrigin(rawValue: Character(UnicodeScalar(UInt8(bitPattern: line.origin))))
                let rawText = String(
                    decoding: UnsafeRawBufferPointer(
                        start: UnsafeRawPointer(line.content),
                        count: Int(line.content_len)
                    ),
                    as: UTF8.self
                )

                return DiffPatchLine(
                    origin: origin,
                    oldLineNumber: line.old_lineno >= 0 ? Int(line.old_lineno) : nil,
                    newLineNumber: line.new_lineno >= 0 ? Int(line.new_lineno) : nil,
                    text: normalizedPatchLineText(origin: origin, rawText: rawText)
                )
            }

            return DiffPatchHunk(
                header: header,
                oldStart: Int(hunk.old_start),
                oldLineCount: Int(hunk.old_lines),
                newStart: Int(hunk.new_start),
                newLineCount: Int(hunk.new_lines),
                lines: lines
            )
        }
    }

    private func normalizedPatchLineText(
        origin: DiffPatchLineOrigin?,
        rawText: String
    ) -> String {
        switch origin {
        case .contextEOFNoNewline, .additionEOFNoNewline, .deletionEOFNoNewline:
            return "\\ No newline at end of file"
        default:
            return rawText.trimmingCharacters(in: .newlines)
        }
    }

    private func makePatch(
        at index: Int,
        includeText: Bool
    ) throws -> DiffPatch {
        try withPatch(at: index) { patchPointer, delta in
            let metadata = try patchMetrics(for: patchPointer, index: index, delta: delta)
            let hunks = try makeHunks(from: patchPointer)
            let text = includeText ? (try streamedPatchText(for: patchPointer, delta: delta)) : ""

            return DiffPatch(
                delta: delta,
                text: text,
                hunks: hunks,
                contextLineCount: metadata.contextLineCount,
                addedLineCount: metadata.addedLineCount,
                removedLineCount: metadata.removedLineCount,
                isBinary: isBinary(delta: delta, renderedPatchText: includeText ? text : nil)
            )
        }
    }

    private func isBinary(
        delta: DiffDelta,
        renderedPatchText: String?
    ) -> Bool {
        let binaryFlag = rawUInt32(of: GIT_DIFF_FLAG_BINARY)
        if (delta.oldFile.flags | delta.newFile.flags) & binaryFlag != 0 {
            return true
        }

        guard let renderedPatchText else {
            return false
        }

        return
            renderedPatchText.contains("Binary files ") ||
            renderedPatchText.contains("GIT binary patch")
    }

    private func streamedPatchText(
        for patchPointer: OpaquePointer,
        delta: DiffDelta
    ) throws -> String {
        let accumulator = PatchPrintAccumulator()
        let payload = Unmanaged.passUnretained(accumulator).toOpaque()

        try check(
            git_patch_print(
                patchPointer,
                { _, _, line, payload in
                    guard
                        let payload,
                        let line
                    else {
                        return 0
                    }

                    let accumulator = Unmanaged<PatchPrintAccumulator>
                        .fromOpaque(payload)
                        .takeUnretainedValue()
                    let diffLine = line.pointee

                    if let content = diffLine.content, diffLine.content_len > 0 {
                        let bytes = UnsafeRawBufferPointer(
                            start: UnsafeRawPointer(content),
                            count: Int(diffLine.content_len)
                        )
                        accumulator.append(bytes)
                    }

                    return 0
                },
                payload
            ),
            context: "git_patch_print"
        )

        return synthesizedPatchText(rawPatch: accumulator.string(), delta: delta)
    }

    private func synthesizedPatchText(
        rawPatch: String,
        delta: DiffDelta
    ) -> String {
        if rawPatch.hasPrefix("diff --git ") {
            return rawPatch
        }

        let oldPath = delta.oldFile.path.map { "a/\($0)" } ?? "/dev/null"
        let newPath = delta.newFile.path.map { "b/\($0)" } ?? "/dev/null"
        return "diff --git \(oldPath) \(newPath)\n\(rawPatch)"
    }

    private func firstMatchingPatchIndex(where predicate: (DiffDelta) -> Bool) -> Int? {
        for index in 0..<deltaCount {
            guard let deltaPointer = git_diff_get_delta(pointer, index) else {
                continue
            }

            let delta = DiffDelta(deltaPointer.pointee)
            if predicate(delta) {
                return index
            }
        }

        return nil
    }

    private func withPatch<T>(
        at index: Int,
        _ body: (OpaquePointer, DiffDelta) throws -> T
    ) throws -> T {
        guard let deltaPointer = git_diff_get_delta(pointer, index) else {
            throw GitError(
                code: GitErrorCode.notFound.rawValue,
                category: .none,
                message: "Diff delta index \(index) is out of range",
                context: "git_diff_get_delta"
            )
        }

        var patchPointer: OpaquePointer?
        try check(git_patch_from_diff(&patchPointer, pointer, index), context: "git_patch_from_diff")

        guard let patchPointer else {
            throw makeMissingPointerError(function: "git_patch_from_diff")
        }

        defer { git_patch_free(patchPointer) }

        let delta = git_patch_get_delta(patchPointer).map { DiffDelta($0.pointee) } ?? DiffDelta(deltaPointer.pointee)
        return try body(patchPointer, delta)
    }

    private func patchMetrics(
        for patchPointer: OpaquePointer,
        index: Int,
        delta: DiffDelta
    ) throws -> DiffPatchMetadata {
        var contextLineCount: Int = 0
        var addedLineCount: Int = 0
        var removedLineCount: Int = 0
        try check(
            git_patch_line_stats(
                &contextLineCount,
                &addedLineCount,
                &removedLineCount,
                patchPointer
            ),
            context: "git_patch_line_stats"
        )

        return DiffPatchMetadata(
            index: index,
            delta: delta,
            byteCount: Int(git_patch_size(patchPointer, 1, 1, 1)),
            contextLineCount: contextLineCount,
            addedLineCount: addedLineCount,
            removedLineCount: removedLineCount
        )
    }
}
