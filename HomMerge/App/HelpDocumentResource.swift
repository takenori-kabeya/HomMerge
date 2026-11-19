import Foundation

/// Resolves bundled Help RTF resource names produced from `docs/Help*.md`.
enum HelpDocumentResource {
    static let englishResourceName = "Help"
    static let japaneseResourceName = "Help.ja"
    static let fileExtension = "rtf"

    /// Uses the primary subtag of the first preferred language (`ja` → `Help.ja`, otherwise `Help`).
    static func rtfResourceName(preferredLanguages: [String]) -> String {
        guard let first = preferredLanguages.first else {
            return englishResourceName
        }
        let primary = first.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: true
        ).first.map(String.init) ?? first
        return primary.lowercased() == "ja" ? japaneseResourceName : englishResourceName
    }

    static func rtfResourceName() -> String {
        rtfResourceName(preferredLanguages: Locale.preferredLanguages)
    }
}

enum HomMergeProjectLinks {
    static let repositoryURL = URL(string: "https://github.com/takenori-kabeya/HomMerge")!
    static let issuesURL = URL(string: "https://github.com/takenori-kabeya/HomMerge/issues")!
}
