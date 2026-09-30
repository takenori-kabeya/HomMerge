import Foundation

/// Options for recursive folder comparison.
public struct FolderCompareOptions: Sendable, Equatable {
    /// When true, names that begin with `.` are skipped.
    public var excludeHidden: Bool

    public init(excludeHidden: Bool = true) {
        self.excludeHidden = excludeHidden
    }

    public static let `default` = FolderCompareOptions()
}

/// Whether an entry is a file or a directory.
public enum FolderEntryKind: Sendable, Equatable {
    case file
    case directory
}

/// Comparison status of a folder entry.
public enum FolderEntryStatus: Sendable, Equatable {
    case identical
    case different
    case leftOnly
    case rightOnly
}

/// One node in a folder comparison tree.
public struct FolderEntry: Sendable, Equatable, Identifiable {
    public var id: String { relativePath }

    public let relativePath: String
    public let name: String
    public let kind: FolderEntryKind
    public let status: FolderEntryStatus
    public let leftURL: URL?
    public let rightURL: URL?
    public let leftModificationDate: Date?
    public let rightModificationDate: Date?
    public let children: [FolderEntry]

    public init(
        relativePath: String,
        name: String,
        kind: FolderEntryKind,
        status: FolderEntryStatus,
        leftURL: URL?,
        rightURL: URL?,
        leftModificationDate: Date? = nil,
        rightModificationDate: Date? = nil,
        children: [FolderEntry] = []
    ) {
        self.relativePath = relativePath
        self.name = name
        self.kind = kind
        self.status = status
        self.leftURL = leftURL
        self.rightURL = rightURL
        self.leftModificationDate = leftModificationDate
        self.rightModificationDate = rightModificationDate
        self.children = children
    }

    /// `true` when both sides exist as files and can be opened in file compare.
    public var canOpenFileCompare: Bool {
        kind == .file && leftURL != nil && rightURL != nil
    }

    /// `.left` / `.right` when both dates exist and one is strictly newer; otherwise `nil`.
    public var newerModificationSide: DiffPaneSide? {
        guard let leftModificationDate, let rightModificationDate else {
            return nil
        }
        if leftModificationDate > rightModificationDate {
            return .left
        }
        if rightModificationDate > leftModificationDate {
            return .right
        }
        return nil
    }
}

/// Result of comparing two directory trees.
public struct FolderCompareResult: Sendable, Equatable {
    public let leftRoot: URL
    public let rightRoot: URL
    public let rootEntries: [FolderEntry]

    public init(leftRoot: URL, rightRoot: URL, rootEntries: [FolderEntry]) {
        self.leftRoot = leftRoot
        self.rightRoot = rightRoot
        self.rootEntries = rootEntries
    }

    /// Depth-first flattening of `rootEntries` (directories appear before their children).
    public var flatEntries: [FolderEntry] {
        var items: [FolderEntry] = []
        func walk(_ entries: [FolderEntry]) {
            for entry in entries {
                items.append(entry)
                walk(entry.children)
            }
        }
        walk(rootEntries)
        return items
    }
}

/// Recursively compares two directories.
public enum FolderScanner {
    public static func compare(
        left: URL,
        right: URL,
        options: FolderCompareOptions = .default
    ) throws -> FolderCompareResult {
        let entries = try compareDirectory(
            left: left,
            right: right,
            relativePath: "",
            options: options
        )
        return FolderCompareResult(leftRoot: left, rightRoot: right, rootEntries: entries)
    }

    private static func compareDirectory(
        left: URL?,
        right: URL?,
        relativePath: String,
        options: FolderCompareOptions
    ) throws -> [FolderEntry] {
        let leftNames = try listedNames(at: left, options: options)
        let rightNames = try listedNames(at: right, options: options)
        let allNames = Array(Set(leftNames).union(rightNames)).sorted()

        return try allNames.map { name in
            let childRelative: String
            if relativePath.isEmpty {
                childRelative = name
            } else {
                childRelative = relativePath + "/" + name
            }

            let leftChild = leftNames.contains(name) ? left!.appendingPathComponent(name) : nil
            let rightChild = rightNames.contains(name) ? right!.appendingPathComponent(name) : nil
            return try compareEntry(
                left: leftChild,
                right: rightChild,
                relativePath: childRelative,
                name: name,
                options: options
            )
        }
    }

    private static func compareEntry(
        left: URL?,
        right: URL?,
        relativePath: String,
        name: String,
        options: FolderCompareOptions
    ) throws -> FolderEntry {
        let leftIsDir = left.map(isDirectory) ?? false
        let rightIsDir = right.map(isDirectory) ?? false

        if left != nil, right == nil {
            if leftIsDir {
                let children = try compareDirectory(
                    left: left,
                    right: nil,
                    relativePath: relativePath,
                    options: options
                )
                return makeEntry(
                    relativePath: relativePath,
                    name: name,
                    kind: .directory,
                    status: .leftOnly,
                    leftURL: left,
                    rightURL: nil,
                    children: children
                )
            }
            return makeEntry(
                relativePath: relativePath,
                name: name,
                kind: .file,
                status: .leftOnly,
                leftURL: left,
                rightURL: nil
            )
        }

        if left == nil, right != nil {
            if rightIsDir {
                let children = try compareDirectory(
                    left: nil,
                    right: right,
                    relativePath: relativePath,
                    options: options
                )
                return makeEntry(
                    relativePath: relativePath,
                    name: name,
                    kind: .directory,
                    status: .rightOnly,
                    leftURL: nil,
                    rightURL: right,
                    children: children
                )
            }
            return makeEntry(
                relativePath: relativePath,
                name: name,
                kind: .file,
                status: .rightOnly,
                leftURL: nil,
                rightURL: right
            )
        }

        // Both exist
        if leftIsDir || rightIsDir {
            // Treat mismatched file/dir as different directory-like nodes with no deep merge.
            if leftIsDir, rightIsDir {
                let children = try compareDirectory(
                    left: left,
                    right: right,
                    relativePath: relativePath,
                    options: options
                )
                let status: FolderEntryStatus = children.allSatisfy { $0.status == .identical }
                    ? .identical
                    : .different
                return makeEntry(
                    relativePath: relativePath,
                    name: name,
                    kind: .directory,
                    status: status,
                    leftURL: left,
                    rightURL: right,
                    children: children
                )
            }

            return makeEntry(
                relativePath: relativePath,
                name: name,
                kind: .directory,
                status: .different,
                leftURL: left,
                rightURL: right,
                children: []
            )
        }

        let status: FolderEntryStatus = try filesAreIdentical(left!, right!) ? .identical : .different
        return makeEntry(
            relativePath: relativePath,
            name: name,
            kind: .file,
            status: status,
            leftURL: left,
            rightURL: right
        )
    }

    private static func makeEntry(
        relativePath: String,
        name: String,
        kind: FolderEntryKind,
        status: FolderEntryStatus,
        leftURL: URL?,
        rightURL: URL?,
        children: [FolderEntry] = []
    ) -> FolderEntry {
        FolderEntry(
            relativePath: relativePath,
            name: name,
            kind: kind,
            status: status,
            leftURL: leftURL,
            rightURL: rightURL,
            leftModificationDate: modificationDate(of: leftURL),
            rightModificationDate: modificationDate(of: rightURL),
            children: children
        )
    }

    private static func modificationDate(of url: URL?) -> Date? {
        guard let url else { return nil }
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func listedNames(at url: URL?, options: FolderCompareOptions) throws -> Set<String> {
        guard let url else { return [] }
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants]
            )
        } catch {
            throw error
        }

        var names = Set<String>()
        for item in contents {
            let name = item.lastPathComponent
            if options.excludeHidden, name.hasPrefix(".") {
                continue
            }
            names.insert(name)
        }
        return names
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private static func filesAreIdentical(_ left: URL, _ right: URL) throws -> Bool {
        let leftValues = try left.resourceValues(forKeys: [.fileSizeKey])
        let rightValues = try right.resourceValues(forKeys: [.fileSizeKey])
        if let leftSize = leftValues.fileSize, let rightSize = rightValues.fileSize, leftSize != rightSize {
            return false
        }
        let leftData = try Data(contentsOf: left)
        let rightData = try Data(contentsOf: right)
        return leftData == rightData
    }
}
