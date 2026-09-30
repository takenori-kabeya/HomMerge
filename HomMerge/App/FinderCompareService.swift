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
        LaunchArgumentsParser.parseOpenFiles(urls.map(\.path))
    }
}
