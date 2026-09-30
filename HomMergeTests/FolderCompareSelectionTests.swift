import DiffEngine
import XCTest
@testable import HomMerge

final class FolderCompareSelectionTests: XCTestCase {
    func testKindClassifiesFilesDirectoriesAndMixedSelections() {
        let file = makeEntry(path: "a.txt", kind: .file, status: .different, left: true, right: true)
        let directory = makeEntry(path: "sub", kind: .directory, status: .leftOnly, left: true, right: false)

        XCTAssertEqual(FolderCompareSelection.kind(for: [file]), .files([file]))
        XCTAssertEqual(FolderCompareSelection.kind(for: [directory]), .directories([directory]))
        XCTAssertEqual(
            FolderCompareSelection.kind(for: [directory, file]),
            .mixed(directories: [directory], files: [file])
        )
        XCTAssertEqual(FolderCompareSelection.kind(for: []), .empty)
    }

    func testCanCompareRequiresOnlyDifferentFiles() {
        let identical = makeEntry(path: "same.txt", kind: .file, status: .identical, left: true, right: true)
        let different = makeEntry(path: "diff.txt", kind: .file, status: .different, left: true, right: true)
        let directory = makeEntry(path: "sub", kind: .directory, status: .leftOnly, left: true, right: false)

        XCTAssertFalse(FolderCompareSelection.canCompare(entries: [identical]))
        XCTAssertTrue(FolderCompareSelection.canCompare(entries: [different]))
        XCTAssertTrue(FolderCompareSelection.canCompare(entries: [identical, different]))
        XCTAssertFalse(FolderCompareSelection.canCompare(entries: [directory]))
        XCTAssertFalse(FolderCompareSelection.canCompare(entries: [different, directory]))
    }

    func testCompareTargetsIncludeOnlyDifferentComparableFiles() {
        let identical = makeEntry(path: "same.txt", kind: .file, status: .identical, left: true, right: true)
        let different = makeEntry(path: "diff.txt", kind: .file, status: .different, left: true, right: true)
        let leftOnly = makeEntry(path: "left.txt", kind: .file, status: .leftOnly, left: true, right: false)

        XCTAssertEqual(
            FolderCompareSelection.compareTargets(entries: [identical, different, leftOnly]),
            [different]
        )
    }

    func testCanCopyRequiresAllEntriesCopyableInDirection() {
        let leftOnly = makeEntry(path: "left.txt", kind: .file, status: .leftOnly, left: true, right: false)
        let rightOnly = makeEntry(path: "right.txt", kind: .file, status: .rightOnly, left: false, right: true)
        let both = makeEntry(path: "both.txt", kind: .file, status: .different, left: true, right: true)

        XCTAssertTrue(
            FolderCompareSelection.canCopy(entries: [leftOnly, both], sourceSide: .left, destinationRootPath: "/right")
        )
        XCTAssertFalse(
            FolderCompareSelection.canCopy(entries: [leftOnly, rightOnly], sourceSide: .left, destinationRootPath: "/right")
        )
        XCTAssertTrue(
            FolderCompareSelection.canCopy(entries: [rightOnly], sourceSide: .right, destinationRootPath: "/left")
        )
        XCTAssertFalse(
            FolderCompareSelection.canCopy(entries: [leftOnly], sourceSide: .right, destinationRootPath: "/left")
        )
        XCTAssertFalse(
            FolderCompareSelection.canCopy(entries: [leftOnly], sourceSide: .left, destinationRootPath: nil)
        )
    }

    func testCanDeleteRequiresOnlyLeftOnlyOrRightOnlyFiles() {
        let leftOnly = makeEntry(path: "left.txt", kind: .file, status: .leftOnly, left: true, right: false)
        let rightOnly = makeEntry(path: "right.txt", kind: .file, status: .rightOnly, left: false, right: true)
        let identical = makeEntry(path: "same.txt", kind: .file, status: .identical, left: true, right: true)
        let different = makeEntry(path: "diff.txt", kind: .file, status: .different, left: true, right: true)
        let leftOnlyDirectory = makeEntry(path: "sub", kind: .directory, status: .leftOnly, left: true, right: false)

        XCTAssertTrue(FolderCompareSelection.canDelete(entries: [leftOnly]))
        XCTAssertTrue(FolderCompareSelection.canDelete(entries: [rightOnly]))
        XCTAssertTrue(FolderCompareSelection.canDelete(entries: [leftOnly, rightOnly]))
        XCTAssertFalse(FolderCompareSelection.canDelete(entries: []))
        XCTAssertFalse(FolderCompareSelection.canDelete(entries: [identical]))
        XCTAssertFalse(FolderCompareSelection.canDelete(entries: [different]))
        XCTAssertFalse(FolderCompareSelection.canDelete(entries: [leftOnlyDirectory]))
        XCTAssertFalse(FolderCompareSelection.canDelete(entries: [leftOnly, different]))
    }

    func testDeleteTargetsAndTrashURLResolveExistingSide() {
        let leftOnly = makeEntry(path: "left.txt", kind: .file, status: .leftOnly, left: true, right: false)
        let rightOnly = makeEntry(path: "right.txt", kind: .file, status: .rightOnly, left: false, right: true)

        XCTAssertEqual(
            FolderCompareSelection.deleteTargets(entries: [rightOnly, leftOnly]),
            [leftOnly, rightOnly]
        )
        XCTAssertEqual(
            FolderCompareSelection.trashURL(for: leftOnly)?.path,
            "/left/left.txt"
        )
        XCTAssertEqual(
            FolderCompareSelection.trashURL(for: rightOnly)?.path,
            "/right/right.txt"
        )
        XCTAssertNil(
            FolderCompareSelection.trashURL(
                for: makeEntry(path: "diff.txt", kind: .file, status: .different, left: true, right: true)
            )
        )
    }

    func testCrossFileCompareOptionsForTwoFilesWithBothSides() {
        let fileB = makeEntry(path: "b.txt", kind: .file, status: .different, left: true, right: true)
        let fileA = makeEntry(path: "a.txt", kind: .file, status: .identical, left: true, right: true)

        let options = FolderCompareSelection.crossFileCompareOptions(entries: [fileB, fileA])
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].title, "Compare Left: a.txt – Right: b.txt")
        XCTAssertTrue(options[0].isEnabled)
        XCTAssertEqual(options[0].leftURL, fileA.leftURL)
        XCTAssertEqual(options[0].rightURL, fileB.rightURL)
        XCTAssertEqual(options[1].title, "Compare Left: b.txt – Right: a.txt")
        XCTAssertTrue(options[1].isEnabled)
        XCTAssertEqual(options[1].leftURL, fileB.leftURL)
        XCTAssertEqual(options[1].rightURL, fileA.rightURL)
    }

    func testCrossFileCompareOptionsLeftOnlyAndRightOnlyEnablesOneDirection() {
        let leftOnly = makeEntry(path: "a.txt", kind: .file, status: .leftOnly, left: true, right: false)
        let rightOnly = makeEntry(path: "b.txt", kind: .file, status: .rightOnly, left: false, right: true)

        let options = FolderCompareSelection.crossFileCompareOptions(entries: [rightOnly, leftOnly])
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].title, "Compare Left: a.txt – Right: b.txt")
        XCTAssertTrue(options[0].isEnabled)
        XCTAssertEqual(options[0].leftURL, leftOnly.leftURL)
        XCTAssertEqual(options[0].rightURL, rightOnly.rightURL)
        XCTAssertEqual(options[1].title, "Compare Left: b.txt – Right: a.txt")
        XCTAssertFalse(options[1].isEnabled)
        XCTAssertNil(options[1].leftURL)
        XCTAssertNil(options[1].rightURL)
    }

    func testCrossFileCompareOptionsBothLeftOnlyAreDisabled() {
        let first = makeEntry(path: "a.txt", kind: .file, status: .leftOnly, left: true, right: false)
        let second = makeEntry(path: "b.txt", kind: .file, status: .leftOnly, left: true, right: false)

        let options = FolderCompareSelection.crossFileCompareOptions(entries: [first, second])
        XCTAssertEqual(options.count, 2)
        XCTAssertFalse(options[0].isEnabled)
        XCTAssertFalse(options[1].isEnabled)
    }

    func testCrossFileCompareOptionsEmptyUnlessExactlyTwoFiles() {
        let file = makeEntry(path: "a.txt", kind: .file, status: .different, left: true, right: true)
        let other = makeEntry(path: "b.txt", kind: .file, status: .different, left: true, right: true)
        let directory = makeEntry(path: "sub", kind: .directory, status: .leftOnly, left: true, right: false)

        XCTAssertTrue(FolderCompareSelection.crossFileCompareOptions(entries: [file]).isEmpty)
        XCTAssertTrue(
            FolderCompareSelection.crossFileCompareOptions(entries: [file, other, directory]).isEmpty
        )
        XCTAssertTrue(
            FolderCompareSelection.crossFileCompareOptions(entries: [file, directory]).isEmpty
        )
    }

    func testCrossFileCompareOptionsUsesRelativePathWhenNamesCollide() {
        let first = makeEntry(path: "dir1/same.txt", kind: .file, status: .different, left: true, right: true)
        let second = makeEntry(path: "dir2/same.txt", kind: .file, status: .different, left: true, right: true)

        let options = FolderCompareSelection.crossFileCompareOptions(entries: [second, first])
        XCTAssertEqual(options[0].title, "Compare Left: dir1/same.txt – Right: dir2/same.txt")
        XCTAssertEqual(options[1].title, "Compare Left: dir2/same.txt – Right: dir1/same.txt")
    }
}

private func makeEntry(
    path: String,
    kind: FolderEntryKind,
    status: FolderEntryStatus,
    left: Bool,
    right: Bool
) -> FolderEntry {
    FolderEntry(
        relativePath: path,
        name: URL(fileURLWithPath: path).lastPathComponent,
        kind: kind,
        status: status,
        leftURL: left ? URL(fileURLWithPath: "/left/\(path)") : nil,
        rightURL: right ? URL(fileURLWithPath: "/right/\(path)") : nil
    )
}
