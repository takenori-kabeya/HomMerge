import Foundation
import Testing
@testable import DiffEngine

@Test func pathKindDetectorIdentifiesFileAndDirectory() throws {
    let root = try makeTempRootForPathKind()
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("a.txt")
    let folder = root.appendingPathComponent("dir")
    try "hello".write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    #expect(PathKindDetector.kind(of: file) == .file)
    #expect(PathKindDetector.kind(of: folder) == .directory)
    #expect(PathKindDetector.kind(of: root.appendingPathComponent("missing")) == nil)
}

@Test func comparePairResolverRequiresBothPaths() {
    let left = URL(fileURLWithPath: "/tmp/left")
    #expect(ComparePairResolver.resolve(left: nil, right: nil) == .incomplete)
    #expect(ComparePairResolver.resolve(left: left, right: nil) == .incomplete)
    #expect(ComparePairResolver.resolve(left: nil, right: left) == .incomplete)
}

@Test func comparePairResolverReturnsFilesWhenBothAreFiles() throws {
    let root = try makeTempRootForPathKind()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left.txt")
    let right = root.appendingPathComponent("right.txt")
    try "a".write(to: left, atomically: true, encoding: .utf8)
    try "b".write(to: right, atomically: true, encoding: .utf8)

    #expect(ComparePairResolver.resolve(left: left, right: right) == .files)
}

@Test func comparePairResolverReturnsFoldersWhenBothAreDirectories() throws {
    let root = try makeTempRootForPathKind()
    defer { try? FileManager.default.removeItem(at: root) }

    let left = root.appendingPathComponent("left")
    let right = root.appendingPathComponent("right")
    try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: right, withIntermediateDirectories: true)

    #expect(ComparePairResolver.resolve(left: left, right: right) == .folders)
}

@Test func comparePairResolverReturnsMismatchWhenKindsDiffer() throws {
    let root = try makeTempRootForPathKind()
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("file.txt")
    let folder = root.appendingPathComponent("folder")
    try "x".write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    #expect(ComparePairResolver.resolve(left: file, right: folder) == .mismatch)
    #expect(ComparePairResolver.resolve(left: folder, right: file) == .mismatch)
}

@Test func comparePairResolverReturnsIncompleteWhenPathMissingOnDisk() throws {
    let root = try makeTempRootForPathKind()
    defer { try? FileManager.default.removeItem(at: root) }

    let existing = root.appendingPathComponent("exists.txt")
    try "x".write(to: existing, atomically: true, encoding: .utf8)
    let missing = root.appendingPathComponent("missing.txt")

    #expect(ComparePairResolver.resolve(left: existing, right: missing) == .incomplete)
}

private func makeTempRootForPathKind() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomMergePathKind-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
