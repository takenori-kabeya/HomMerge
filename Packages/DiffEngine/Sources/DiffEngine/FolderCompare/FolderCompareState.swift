import Foundation

/// Mutable state for a folder comparison session.
public struct FolderCompareState: Sendable, Equatable {
    public private(set) var leftRoot: URL?
    public private(set) var rightRoot: URL?
    public private(set) var result: FolderCompareResult?
    public var options: FolderCompareOptions {
        didSet {
            if let leftRoot, let rightRoot {
                try? compare(left: leftRoot, right: rightRoot)
            }
        }
    }

    /// When true, identical entries are hidden from `displayedEntries`.
    public var showOnlyDifferences: Bool

    public init(
        options: FolderCompareOptions = .default,
        showOnlyDifferences: Bool = false
    ) {
        self.leftRoot = nil
        self.rightRoot = nil
        self.result = nil
        self.options = options
        self.showOnlyDifferences = showOnlyDifferences
    }

    public var hasResult: Bool {
        result != nil
    }

    public var entries: [FolderEntry] {
        result?.rootEntries ?? []
    }

    public var displayedEntries: [FolderEntry] {
        guard showOnlyDifferences else {
            return entries
        }
        return entries.compactMap(filterDifferences)
    }

    public mutating func compare(left: URL, right: URL) throws {
        leftRoot = left
        rightRoot = right
        result = try FolderScanner.compare(left: left, right: right, options: options)
    }

    public mutating func clear() {
        leftRoot = nil
        rightRoot = nil
        result = nil
    }

    private func filterDifferences(_ entry: FolderEntry) -> FolderEntry? {
        if entry.kind == .directory {
            let children = entry.children.compactMap(filterDifferences)
            if entry.status == .identical, children.isEmpty {
                return nil
            }
            if entry.status == .identical, !children.isEmpty {
                return FolderEntry(
                    relativePath: entry.relativePath,
                    name: entry.name,
                    kind: entry.kind,
                    status: .different,
                    leftURL: entry.leftURL,
                    rightURL: entry.rightURL,
                    leftModificationDate: entry.leftModificationDate,
                    rightModificationDate: entry.rightModificationDate,
                    children: children
                )
            }
            return FolderEntry(
                relativePath: entry.relativePath,
                name: entry.name,
                kind: entry.kind,
                status: entry.status,
                leftURL: entry.leftURL,
                rightURL: entry.rightURL,
                leftModificationDate: entry.leftModificationDate,
                rightModificationDate: entry.rightModificationDate,
                children: children
            )
        }

        return entry.status == .identical ? nil : entry
    }
}
