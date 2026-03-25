#if os(macOS)
@_exported import Clibgit2System
#elseif os(iOS) || os(visionOS)
@_exported import Clibgit2Binary
#endif
