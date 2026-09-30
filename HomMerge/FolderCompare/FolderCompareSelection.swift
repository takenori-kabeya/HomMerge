import DiffEngine
import Foundation

enum FolderSelectionKind: Equatable {
    case empty
    case files([FolderEntry])
    case directories([FolderEntry])
    case mixed(directories: [FolderEntry], files: [FolderEntry])
}

struct CrossFileCompareOption: Equatable, Identifiable {
    var id: String { title }
    var title: String
    var isEnabled: Bool
    var leftURL: URL?
    var rightURL: URL?
}

enum FolderCompareSelection {
    static func kind(for entries: [FolderEntry]) -> FolderSelectionKind {
        guard !entries.isEmpty else { return .empty }

        let files = entries.filter { $0.kind == .file }.sorted { $0.relativePath < $1.relativePath }
        let directories = entries.filter { $0.kind == .directory }.sorted { $0.relativePath < $1.relativePath }

        if files.count == entries.count {
            return .files(files)
        }
        if directories.count == entries.count {
            return .directories(directories)
        }
        return .mixed(directories: directories, files: files)
    }

    /// Cross-file compare menu options when exactly two files are selected.
    /// File1 / File2 are ordered by ascending `relativePath`.
    static func crossFileCompareOptions(entries: [FolderEntry]) -> [CrossFileCompareOption] {
        guard case .files(let files) = kind(for: entries), files.count == 2 else {
            return []
        }
        let first = files[0]
        let second = files[1]
        let firstLabel = displayName(for: first, collidingWith: second)
        let secondLabel = displayName(for: second, collidingWith: first)
        return [
            option(leftSource: first, rightSource: second, leftLabel: firstLabel, rightLabel: secondLabel),
            option(leftSource: second, rightSource: first, leftLabel: secondLabel, rightLabel: firstLabel),
        ]
    }

    static func compareTargets(entries: [FolderEntry]) -> [FolderEntry] {
        entries
            .filter { $0.kind == .file && $0.status == .different && $0.canOpenFileCompare }
            .sorted { $0.relativePath < $1.relativePath }
    }

    static func canCompare(entries: [FolderEntry]) -> Bool {
        guard case .files = kind(for: entries) else { return false }
        return !compareTargets(entries: entries).isEmpty
    }

    static func canCopy(
        entries: [FolderEntry],
        sourceSide: DiffPaneSide,
        destinationRootPath: String?
    ) -> Bool {
        guard destinationRootPath != nil, !entries.isEmpty else { return false }
        return entries.allSatisfy { isEntryCopyable($0, sourceSide: sourceSide) }
    }

    static func isEntryCopyable(_ entry: FolderEntry, sourceSide: DiffPaneSide) -> Bool {
        guard entry.kind == .file || entry.kind == .directory else { return false }
        switch sourceSide {
        case .left:
            return entry.leftURL != nil
        case .right:
            return entry.rightURL != nil
        }
    }

    static func canDelete(entries: [FolderEntry]) -> Bool {
        guard !entries.isEmpty else { return false }
        return entries.allSatisfy(isDeletableFile)
    }

    static func deleteTargets(entries: [FolderEntry]) -> [FolderEntry] {
        guard canDelete(entries: entries) else { return [] }
        return entries
            .filter(isDeletableFile)
            .sorted { $0.relativePath < $1.relativePath }
    }

    static func trashURL(for entry: FolderEntry) -> URL? {
        switch entry.status {
        case .leftOnly:
            return entry.leftURL
        case .rightOnly:
            return entry.rightURL
        case .identical, .different:
            return nil
        }
    }

    private static func isDeletableFile(_ entry: FolderEntry) -> Bool {
        entry.kind == .file && (entry.status == .leftOnly || entry.status == .rightOnly)
    }

    private static func displayName(for entry: FolderEntry, collidingWith other: FolderEntry) -> String {
        if entry.name == other.name {
            return entry.relativePath
        }
        return entry.name
    }

    private static func option(
        leftSource: FolderEntry,
        rightSource: FolderEntry,
        leftLabel: String,
        rightLabel: String
    ) -> CrossFileCompareOption {
        let leftURL = leftSource.leftURL
        let rightURL = rightSource.rightURL
        let enabled = leftURL != nil && rightURL != nil
        return CrossFileCompareOption(
            title: "Compare Left: \(leftLabel) – Right: \(rightLabel)",
            isEnabled: enabled,
            leftURL: enabled ? leftURL : nil,
            rightURL: enabled ? rightURL : nil
        )
    }
}
