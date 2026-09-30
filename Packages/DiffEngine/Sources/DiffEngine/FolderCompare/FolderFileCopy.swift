import Foundation

/// One file copy in a recursive folder-copy plan.
public struct FolderCopyOperation: Sendable, Equatable {
    public let sourceURL: URL
    public let destinationURL: URL
    public let relativePath: String
    public let requiresOverwriteConfirmation: Bool

    public init(
        sourceURL: URL,
        destinationURL: URL,
        relativePath: String,
        requiresOverwriteConfirmation: Bool
    ) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.relativePath = relativePath
        self.requiresOverwriteConfirmation = requiresOverwriteConfirmation
    }
}

/// Copies files between folder-compare roots.
public enum FolderFileCopy {
    public enum Error: Swift.Error, Equatable, LocalizedError {
        case sourceMissing
        case sourceNotFile
        case destinationExists

        public var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "The source file could not be found."
            case .sourceNotFile:
                return "The source path is not a file."
            case .destinationExists:
                return "The destination file already exists."
            }
        }
    }

    /// Builds the destination URL under `root` for a compare `relativePath`.
    public static func destinationURL(root: URL, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(root) { partial, component in
                partial.appendingPathComponent(String(component))
            }
    }

    /// Builds a recursive copy plan for `entry` from `sourceSide` into `destinationRoot`.
    ///
    /// Identical files that already exist at the destination are omitted. Different files that
    /// already exist require overwrite confirmation before executing the plan.
    public static func copyPlan(
        for entry: FolderEntry,
        destinationRoot: URL,
        sourceSide: DiffPaneSide,
        options: FolderCompareOptions = .default,
        fileManager: FileManager = .default
    ) throws -> [FolderCopyOperation] {
        let fileEntries = try collectFileEntries(
            from: entry,
            sourceSide: sourceSide,
            options: options,
            fileManager: fileManager
        )
        return try fileEntries.compactMap { fileEntry in
            try copyOperation(
                for: fileEntry,
                sourceSide: sourceSide,
                destinationRoot: destinationRoot,
                fileManager: fileManager
            )
        }
    }

    /// Merges multiple copy plans, deduplicating by `relativePath` (later plans win).
    public static func mergeCopyPlans(_ plans: [[FolderCopyOperation]]) -> [FolderCopyOperation] {
        var byPath: [String: FolderCopyOperation] = [:]
        for plan in plans {
            for operation in plan {
                byPath[operation.relativePath] = operation
            }
        }
        return byPath.values.sorted { $0.relativePath < $1.relativePath }
    }

    /// Executes every operation in `plan` using `copyFile`.
    public static func executeCopyPlan(
        _ plan: [FolderCopyOperation],
        fileManager: FileManager = .default
    ) throws {
        for operation in plan {
            let destinationExists = fileManager.fileExists(atPath: operation.destinationURL.path)
            try copyFile(
                from: operation.sourceURL,
                to: operation.destinationURL,
                overwrite: destinationExists,
                fileManager: fileManager
            )
        }
    }

    /// Copies `source` to `destination`.
    ///
    /// - When `overwrite` is `false` and the destination already exists, throws `.destinationExists`.
    /// - Creates intermediate parent directories when needed.
    public static func copyFile(
        from source: URL,
        to destination: URL,
        overwrite: Bool,
        fileManager: FileManager = .default
    ) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw Error.sourceMissing
        }
        guard !isDirectory.boolValue else {
            throw Error.sourceNotFile
        }

        if fileManager.fileExists(atPath: destination.path) {
            guard overwrite else {
                throw Error.destinationExists
            }
            try fileManager.removeItem(at: destination)
        }

        let parent = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        try fileManager.copyItem(at: source, to: destination)
    }

    private static func copyOperation(
        for fileEntry: FolderEntry,
        sourceSide: DiffPaneSide,
        destinationRoot: URL,
        fileManager: FileManager
    ) throws -> FolderCopyOperation? {
        guard fileEntry.kind == .file,
              let sourceURL = sourceURL(for: fileEntry, side: sourceSide)
        else {
            return nil
        }

        let destinationURL = destinationURL(root: destinationRoot, relativePath: fileEntry.relativePath)
        let destinationExists = fileManager.fileExists(atPath: destinationURL.path)

        if fileEntry.status == .identical, destinationExists {
            return nil
        }

        let requiresOverwriteConfirmation = fileEntry.status == .different && destinationExists
        return FolderCopyOperation(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            relativePath: fileEntry.relativePath,
            requiresOverwriteConfirmation: requiresOverwriteConfirmation
        )
    }

    private static func sourceURL(for entry: FolderEntry, side: DiffPaneSide) -> URL? {
        switch side {
        case .left: return entry.leftURL
        case .right: return entry.rightURL
        }
    }

    private static func collectFileEntries(
        from entry: FolderEntry,
        sourceSide: DiffPaneSide,
        options: FolderCompareOptions,
        fileManager: FileManager
    ) throws -> [FolderEntry] {
        if entry.kind == .file {
            guard sourceURL(for: entry, side: sourceSide) != nil else { return [] }
            return [entry]
        }

        if !entry.children.isEmpty {
            var files: [FolderEntry] = []
            for child in entry.children {
                files.append(contentsOf: try collectFileEntries(
                    from: child,
                    sourceSide: sourceSide,
                    options: options,
                    fileManager: fileManager
                ))
            }
            return files
        }

        guard let directoryURL = sourceURL(for: entry, side: sourceSide) else { return [] }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return []
        }

        let prefix = entry.relativePath
        let enumerated = try enumerateFiles(
            at: directoryURL,
            relativePathPrefix: prefix,
            options: options,
            fileManager: fileManager
        )
        return enumerated.map { relativePath, url in
            FolderEntry(
                relativePath: relativePath,
                name: URL(fileURLWithPath: relativePath).lastPathComponent,
                kind: .file,
                status: sourceSide == .left ? .leftOnly : .rightOnly,
                leftURL: sourceSide == .left ? url : nil,
                rightURL: sourceSide == .right ? url : nil
            )
        }
    }

    private static func enumerateFiles(
        at directoryURL: URL,
        relativePathPrefix: String,
        options: FolderCompareOptions,
        fileManager: FileManager
    ) throws -> [(relativePath: String, url: URL)] {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [(String, URL)] = []
        let prefix = relativePathPrefix.isEmpty ? "" : relativePathPrefix + "/"
        let directoryPath = directoryURL.standardizedFileURL.path

        for case let itemURL as URL in enumerator {
            let values = try itemURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true else {
                continue
            }

            let name = itemURL.lastPathComponent
            if options.excludeHidden, name.hasPrefix(".") {
                continue
            }

            let absolutePath = itemURL.standardizedFileURL.path
            guard absolutePath.hasPrefix(directoryPath) else { continue }
            let suffix = absolutePath.dropFirst(directoryPath.count)
            let trimmed = suffix.hasPrefix("/") ? String(suffix.dropFirst()) : String(suffix)
            let relativePath = prefix + trimmed
            files.append((relativePath, itemURL))
        }

        return files.sorted { $0.0 < $1.0 }
    }
}
