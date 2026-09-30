import Foundation
import Testing
@testable import DiffEngine

@Test func folderFileCopyDestinationURLAppendsRelativePath() {
    let root = URL(fileURLWithPath: "/tmp/root", isDirectory: true)
    let dest = FolderFileCopy.destinationURL(root: root, relativePath: "sub/a.txt")
    #expect(dest.path == "/tmp/root/sub/a.txt")
}

@Test func folderFileCopyCreatesMissingDestinationAndParents() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("source.txt")
    let dest = root.appendingPathComponent("nested/dir/dest.txt")
    try write("hello", to: source)

    try FolderFileCopy.copyFile(from: source, to: dest, overwrite: false)

    let copied = try String(contentsOf: dest, encoding: .utf8)
    #expect(copied == "hello")
}

@Test func folderFileCopyOverwriteTrueReplacesExistingFile() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("source.txt")
    let dest = root.appendingPathComponent("dest.txt")
    try write("new", to: source)
    try write("old", to: dest)

    try FolderFileCopy.copyFile(from: source, to: dest, overwrite: true)

    let copied = try String(contentsOf: dest, encoding: .utf8)
    #expect(copied == "new")
}

@Test func folderFileCopyOverwriteFalseThrowsWhenDestinationExists() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("source.txt")
    let dest = root.appendingPathComponent("dest.txt")
    try write("new", to: source)
    try write("old", to: dest)

    #expect(throws: FolderFileCopy.Error.destinationExists) {
        try FolderFileCopy.copyFile(from: source, to: dest, overwrite: false)
    }

    let remaining = try String(contentsOf: dest, encoding: .utf8)
    #expect(remaining == "old")
}

@Test func folderCopyPlanLeftOnlyFolderCopiesAllChildren() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(
        at: left.appendingPathComponent("sub"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("a", to: left.appendingPathComponent("sub/a.txt"))
    try write("b", to: left.appendingPathComponent("sub/b.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let sub = try #require(result.rootEntries.first { $0.name == "sub" })
    #expect(sub.kind == .directory)

    let plan = try FolderFileCopy.copyPlan(for: sub, destinationRoot: right, sourceSide: .left)
    #expect(plan.count == 2)
    #expect(plan.allSatisfy { !$0.requiresOverwriteConfirmation })

    try FolderFileCopy.executeCopyPlan(plan)
    #expect(FileManager.default.fileExists(atPath: right.appendingPathComponent("sub/a.txt").path))
    #expect(FileManager.default.fileExists(atPath: right.appendingPathComponent("sub/b.txt").path))
}

@Test func folderCopyPlanDifferentFileRequiresConfirmation() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("alpha", to: left.appendingPathComponent("a.txt"))
    try write("beta", to: right.appendingPathComponent("a.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let entry = try #require(result.rootEntries.first)

    let plan = try FolderFileCopy.copyPlan(for: entry, destinationRoot: right, sourceSide: .left)
    #expect(plan.count == 1)
    #expect(plan[0].requiresOverwriteConfirmation)
}

@Test func folderCopyPlanIdenticalFileIsSkipped() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("hello", to: left.appendingPathComponent("a.txt"))
    try write("hello", to: right.appendingPathComponent("a.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let entry = try #require(result.rootEntries.first)

    let plan = try FolderFileCopy.copyPlan(for: entry, destinationRoot: right, sourceSide: .left)
    #expect(plan.isEmpty)
}

@Test func folderCopyPlanMixedFolderClassifiesOperations() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(
        at: left.appendingPathComponent("sub"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: right.appendingPathComponent("sub"),
        withIntermediateDirectories: true
    )
    try write("left only", to: left.appendingPathComponent("sub/only-left.txt"))
    try write("diff A", to: left.appendingPathComponent("sub/diff.txt"))
    try write("same", to: left.appendingPathComponent("sub/same.txt"))
    try write("diff B", to: right.appendingPathComponent("sub/diff.txt"))
    try write("same", to: right.appendingPathComponent("sub/same.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let sub = try #require(result.rootEntries.first { $0.name == "sub" })

    let plan = try FolderFileCopy.copyPlan(for: sub, destinationRoot: right, sourceSide: .left)
    #expect(plan.count == 2)

    let byPath = Dictionary(uniqueKeysWithValues: plan.map { ($0.relativePath, $0) })
    #expect(byPath["sub/only-left.txt"]?.requiresOverwriteConfirmation == false)
    #expect(byPath["sub/diff.txt"]?.requiresOverwriteConfirmation == true)
    #expect(byPath["sub/same.txt"] == nil)
}

@Test func folderCopyPlanExecuteUpdatesDisk() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(
        at: left.appendingPathComponent("sub"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: right.appendingPathComponent("sub"),
        withIntermediateDirectories: true
    )
    try write("left only", to: left.appendingPathComponent("sub/only-left.txt"))
    try write("diff A", to: left.appendingPathComponent("sub/diff.txt"))
    try write("same", to: left.appendingPathComponent("sub/same.txt"))
    try write("diff B", to: right.appendingPathComponent("sub/diff.txt"))
    try write("same", to: right.appendingPathComponent("sub/same.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let sub = try #require(result.rootEntries.first { $0.name == "sub" })
    let plan = try FolderFileCopy.copyPlan(for: sub, destinationRoot: right, sourceSide: .left)

    try FolderFileCopy.executeCopyPlan(plan)

    let onlyLeft = try String(
        contentsOf: right.appendingPathComponent("sub/only-left.txt"),
        encoding: .utf8
    )
    #expect(onlyLeft == "left only")

    let diff = try String(contentsOf: right.appendingPathComponent("sub/diff.txt"), encoding: .utf8)
    #expect(diff == "diff A")

    let same = try String(contentsOf: right.appendingPathComponent("sub/same.txt"), encoding: .utf8)
    #expect(same == "same")
}

@Test func mergeCopyPlansCombinesMultipleFolderPlans() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(
        at: left.appendingPathComponent("sub1"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: left.appendingPathComponent("sub2"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("a", to: left.appendingPathComponent("sub1/a.txt"))
    try write("b", to: left.appendingPathComponent("sub2/b.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let sub1 = try #require(result.rootEntries.first { $0.name == "sub1" })
    let sub2 = try #require(result.rootEntries.first { $0.name == "sub2" })

    let plan1 = try FolderFileCopy.copyPlan(for: sub1, destinationRoot: right, sourceSide: .left)
    let plan2 = try FolderFileCopy.copyPlan(for: sub2, destinationRoot: right, sourceSide: .left)
    let merged = FolderFileCopy.mergeCopyPlans([plan1, plan2])

    #expect(merged.count == 2)
    #expect(merged.map(\.relativePath) == ["sub1/a.txt", "sub2/b.txt"])
}

@Test func mergeCopyPlansDeduplicatesByRelativePath() {
    let sourceA = URL(fileURLWithPath: "/tmp/left/a.txt")
    let sourceB = URL(fileURLWithPath: "/tmp/left-b/a.txt")
    let destination = URL(fileURLWithPath: "/tmp/right/a.txt")
    let first = FolderCopyOperation(
        sourceURL: sourceA,
        destinationURL: destination,
        relativePath: "a.txt",
        requiresOverwriteConfirmation: false
    )
    let second = FolderCopyOperation(
        sourceURL: sourceB,
        destinationURL: destination,
        relativePath: "a.txt",
        requiresOverwriteConfirmation: true
    )

    let merged = FolderFileCopy.mergeCopyPlans([[first], [second]])

    #expect(merged.count == 1)
    #expect(merged[0].sourceURL == sourceB)
    #expect(merged[0].requiresOverwriteConfirmation)
}

@Test func folderFileCopyThrowsWhenSourceMissing() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("missing.txt")
    let dest = root.appendingPathComponent("dest.txt")

    #expect(throws: FolderFileCopy.Error.sourceMissing) {
        try FolderFileCopy.copyFile(from: source, to: dest, overwrite: false)
    }
}

// MARK: - Helpers

private func makeTempRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomMergeFolderFileCopyTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ text: String, to url: URL) throws {
    try text.data(using: .utf8)!.write(to: url)
}
