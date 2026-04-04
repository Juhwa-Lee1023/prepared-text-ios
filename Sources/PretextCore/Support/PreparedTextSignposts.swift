import Foundation

#if canImport(OSLog)
import OSLog
#endif

enum PreparedTextSignposts {
    static func measure<T>(_ name: StaticString, _ block: () -> T) -> T {
        #if canImport(OSLog)
        if #available(iOS 15.0, macOS 12.0, *) {
            let signposter = OSSignposter(subsystem: "prepared-text-ios", category: "engine")
            let state = signposter.beginInterval(name)
            defer { signposter.endInterval(name, state) }
            return block()
        }
        #endif

        return block()
    }
}
