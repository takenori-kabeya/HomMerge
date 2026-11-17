import AppKit
import Foundation

enum FinderCompareService {
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            return urls
        }
        if let paths = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            return paths.map { URL(fileURLWithPath: $0) }
        }
        return []
    }

    static func comparisonRequest(fromFileURLs urls: [URL]) -> LaunchComparisonRequest? {
        guard urls.count == 2 else {
            return nil
        }
        // Keep the original file URLs (do not rebuild from path strings) so
        // security-scoped access from Services / pasteboard is preserved.
        return LaunchComparisonRequest(
            left: urls[0].standardizedFileURL,
            right: urls[1].standardizedFileURL
        )
    }
}
