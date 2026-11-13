import Foundation

enum SecurityScopedBookmark {
    /// Creates a security-scoped bookmark for later restoration under App Sandbox.
    static func makeBookmark(from url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves a security-scoped bookmark to a file URL.
    /// Callers own `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`.
    static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
