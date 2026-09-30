import Foundation
import Testing
@testable import DiffEngine

@Test func folderScannerIdenticalFiles() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("hello\n", to: left.appendingPathComponent("a.txt"))
    try write("hello\n", to: right.appendingPathComponent("a.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    #expect(result.rootEntries.count == 1)
    #expect(result.rootEntries[0].name == "a.txt")
    #expect(result.rootEntries[0].kind == .file)
    #expect(result.rootEntries[0].status == .identical)
    #expect(result.rootEntries[0].relativePath == "a.txt")
    #expect(result.rootEntries[0].leftURL != nil)
    #expect(result.rootEntries[0].rightURL != nil)
}

@Test func folderScannerDetectsDifferentContent() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("alpha", to: left.appendingPathComponent("a.txt"))
    try write("beta", to: right.appendingPathComponent("a.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    #expect(result.rootEntries[0].status == .different)
}

@Test func folderScannerLeftOnlyAndRightOnly() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("L", to: left.appendingPathComponent("only-left.txt"))
    try write("R", to: right.appendingPathComponent("only-right.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let byName = Dictionary(uniqueKeysWithValues: result.rootEntries.map { ($0.name, $0) })

    #expect(byName["only-left.txt"]?.status == .leftOnly)
    #expect(byName["only-left.txt"]?.rightURL == nil)
    #expect(byName["only-right.txt"]?.status == .rightOnly)
    #expect(byName["only-right.txt"]?.leftURL == nil)
}

@Test func folderScannerRecursesIntoSubdirectories() throws {
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
    try write("x", to: left.appendingPathComponent("sub/b.txt"))
    try write("y", to: right.appendingPathComponent("sub/b.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    #expect(result.rootEntries.count == 1)
    let sub = result.rootEntries[0]
    #expect(sub.kind == .directory)
    #expect(sub.name == "sub")
    #expect(sub.status == .different)
    #expect(sub.children.count == 1)
    #expect(sub.children[0].relativePath == "sub/b.txt")
    #expect(sub.children[0].status == .different)
}

@Test func folderScannerMarksDirectoryIdenticalWhenChildrenMatch() throws {
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
    try write("same", to: left.appendingPathComponent("sub/b.txt"))
    try write("same", to: right.appendingPathComponent("sub/b.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    #expect(result.rootEntries[0].status == .identical)
    #expect(result.rootEntries[0].children[0].status == .identical)
}

@Test func folderScannerExcludesHiddenEntriesByDefault() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("visible", to: left.appendingPathComponent("a.txt"))
    try write("visible", to: right.appendingPathComponent("a.txt"))
    try write("secret", to: left.appendingPathComponent(".hidden"))
    try write("secret", to: right.appendingPathComponent(".hidden"))

    let result = try FolderScanner.compare(left: left, right: right)
    #expect(result.rootEntries.map(\.name) == ["a.txt"])
}

@Test func folderScannerCanIncludeHiddenEntries() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("secret-l", to: left.appendingPathComponent(".hidden"))
    try write("secret-r", to: right.appendingPathComponent(".hidden"))

    let options = FolderCompareOptions(excludeHidden: false)
    let result = try FolderScanner.compare(left: left, right: right, options: options)
    #expect(result.rootEntries.count == 1)
    #expect(result.rootEntries[0].name == ".hidden")
    #expect(result.rootEntries[0].status == .different)
}

@Test func folderScannerFlatEntriesAreDepthFirst() throws {
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
    try write("a", to: left.appendingPathComponent("a.txt"))
    try write("a", to: right.appendingPathComponent("a.txt"))
    try write("b", to: left.appendingPathComponent("sub/b.txt"))
    try write("b", to: right.appendingPathComponent("sub/b.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    #expect(result.flatEntries.map(\.relativePath) == ["a.txt", "sub", "sub/b.txt"])
}

@Test func folderCompareStateLoadsAndFiltersDifferences() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("same", to: left.appendingPathComponent("same.txt"))
    try write("same", to: right.appendingPathComponent("same.txt"))
    try write("L", to: left.appendingPathComponent("diff.txt"))
    try write("R", to: right.appendingPathComponent("diff.txt"))

    var state = FolderCompareState()
    try state.compare(left: left, right: right)
    #expect(state.entries.count == 2)
    #expect(state.hasResult == true)

    state.showOnlyDifferences = true
    #expect(state.displayedEntries.map(\.name) == ["diff.txt"])
}

@Test func folderCompareStateSelectableFileRequiresBothSides() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("L", to: left.appendingPathComponent("only-left.txt"))
    try write("both-l", to: left.appendingPathComponent("both.txt"))
    try write("both-r", to: right.appendingPathComponent("both.txt"))

    var state = FolderCompareState()
    try state.compare(left: left, right: right)

    let onlyLeft = state.entries.first { $0.name == "only-left.txt" }!
    let both = state.entries.first { $0.name == "both.txt" }!
    #expect(onlyLeft.canOpenFileCompare == false)
    #expect(both.canOpenFileCompare == true)
}


@Test func folderScannerCapturesModificationDatesAndNewerSide() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)

    let leftFile = left.appendingPathComponent("a.txt")
    let rightFile = right.appendingPathComponent("a.txt")
    try write("same", to: leftFile)
    try write("same", to: rightFile)

    let older = Date(timeIntervalSince1970: 1_700_000_000)
    let newer = Date(timeIntervalSince1970: 1_700_100_000)
    try FileManager.default.setAttributes([.modificationDate: older], ofItemAtPath: leftFile.path)
    try FileManager.default.setAttributes([.modificationDate: newer], ofItemAtPath: rightFile.path)

    let result = try FolderScanner.compare(left: left, right: right)
    let entry = result.rootEntries[0]
    #expect(entry.leftModificationDate != nil)
    #expect(entry.rightModificationDate != nil)
    #expect(entry.newerModificationSide == .right)

    try FileManager.default.setAttributes([.modificationDate: newer], ofItemAtPath: leftFile.path)
    try FileManager.default.setAttributes([.modificationDate: older], ofItemAtPath: rightFile.path)
    let flipped = try FolderScanner.compare(left: left, right: right).rootEntries[0]
    #expect(flipped.newerModificationSide == .left)

    try FileManager.default.setAttributes([.modificationDate: older], ofItemAtPath: leftFile.path)
    try FileManager.default.setAttributes([.modificationDate: older], ofItemAtPath: rightFile.path)
    let equal = try FolderScanner.compare(left: left, right: right).rootEntries[0]
    #expect(equal.newerModificationSide == nil)
}

@Test func folderScannerOneSidedEntryHasNilDateOnMissingSide() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)
    try write("L", to: left.appendingPathComponent("only-left.txt"))
    try write("R", to: right.appendingPathComponent("only-right.txt"))

    let result = try FolderScanner.compare(left: left, right: right)
    let byName = Dictionary(uniqueKeysWithValues: result.rootEntries.map { ($0.name, $0) })

    let onlyLeft = byName["only-left.txt"]!
    #expect(onlyLeft.leftModificationDate != nil)
    #expect(onlyLeft.rightModificationDate == nil)
    #expect(onlyLeft.newerModificationSide == nil)

    let onlyRight = byName["only-right.txt"]!
    #expect(onlyRight.leftModificationDate == nil)
    #expect(onlyRight.rightModificationDate != nil)
    #expect(onlyRight.newerModificationSide == nil)
}

// MARK: - Helpers

private func makeTempRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomMergeFolderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ text: String, to url: URL) throws {
    try text.data(using: .utf8)!.write(to: url)
}
