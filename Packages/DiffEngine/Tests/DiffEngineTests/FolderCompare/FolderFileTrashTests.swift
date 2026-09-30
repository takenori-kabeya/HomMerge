import Foundation
import Testing
@testable import DiffEngine

@Test func folderFileTrashMovesExistingFileToTrash() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let fileURL = root.appendingPathComponent("delete-me.txt")
    try write("trash me", to: fileURL)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))

    try FolderFileTrash.moveToTrash(at: fileURL)

    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
}

@Test func folderFileTrashThrowsWhenFileMissing() throws {
    let root = try makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let missingURL = root.appendingPathComponent("missing.txt")

    #expect(throws: FolderFileTrash.Error.missing) {
        try FolderFileTrash.moveToTrash(at: missingURL)
    }
}

// MARK: - Helpers

private func makeTempRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomMergeFolderFileTrashTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ text: String, to url: URL) throws {
    try text.data(using: .utf8)!.write(to: url)
}
