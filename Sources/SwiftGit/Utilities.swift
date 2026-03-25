import Foundation
import Libgit2Bindings

@inline(__always)
internal func gitString(_ value: UnsafePointer<CChar>?) -> String? {
    guard let value else {
        return nil
    }

    return String(cString: value)
}

@inline(__always)
internal func rawUInt32<T>(of value: T) -> UInt32 {
    withUnsafeBytes(of: value) { $0.load(as: UInt32.self) }
}

@inline(__always)
internal func rawInt32<T>(of value: T) -> Int32 {
    withUnsafeBytes(of: value) { $0.load(as: Int32.self) }
}

@inline(__always)
internal func copiedData(from pointer: UnsafeRawPointer?, count: Int) -> Data {
    guard let pointer, count > 0 else {
        return Data()
    }

    return Data(bytes: pointer, count: count)
}

@discardableResult
internal func check(_ code: Int32, context: String? = nil) throws -> Int32 {
    guard code >= 0 else {
        throw GitError.lastError(code: code, context: context)
    }

    return code
}

internal func withOptionalCString<T>(
    _ value: String?,
    _ body: (UnsafePointer<CChar>?) throws -> T
) rethrows -> T {
    guard let value else {
        return try body(nil)
    }

    return try value.withCString(body)
}

internal func bufferString(_ buffer: git_buf) -> String {
    guard let baseAddress = buffer.ptr else {
        return ""
    }

    let bytes = UnsafeRawBufferPointer(
        start: UnsafeRawPointer(baseAddress),
        count: Int(buffer.size)
    )

    return String(decoding: bytes, as: UTF8.self)
}

internal func strings(from array: git_strarray) -> [String] {
    guard let strings = array.strings else {
        return []
    }

    return (0..<Int(array.count)).compactMap { index in
        gitString(strings[index])
    }
}

internal func withGitStrArray<T>(
    _ values: [String],
    _ body: (git_strarray) throws -> T
) throws -> T {
    var duplicated = values.map { value in
        strdup(value)
    }
    defer {
        for pointer in duplicated {
            free(pointer)
        }
    }

    return try duplicated.withUnsafeMutableBufferPointer { buffer in
        let array = git_strarray(
            strings: buffer.baseAddress,
            count: buffer.count
        )
        return try body(array)
    }
}

@discardableResult
internal func withGitBuffer<T>(
    _ body: (UnsafeMutablePointer<git_buf>) throws -> T
) rethrows -> (T, String) {
    var buffer = git_buf()
    defer { git_buf_dispose(&buffer) }
    let result = try body(&buffer)
    return (result, bufferString(buffer))
}

internal func makeFileURL(path: String?, isDirectory: Bool) -> URL? {
    guard let path else {
        return nil
    }

    return URL(fileURLWithPath: path, isDirectory: isDirectory)
}

internal func makeMissingPointerError(function: String) -> GitError {
    GitError(
        code: GitErrorCode.generic.rawValue,
        category: .none,
        message: "libgit2 returned a null pointer",
        context: function
    )
}
