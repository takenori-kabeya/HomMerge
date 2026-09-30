import Foundation
import Testing
@testable import DiffEngine

@Test func pathHeaderLabelUsesPlaceholdersWhenPathsMissing() {
    let bothMissing = PathHeaderLabel.pair(leftPath: nil, rightPath: nil, maxCharactersPerSide: 40)
    #expect(bothMissing.left == "Left")
    #expect(bothMissing.right == "Right")

    let leftOnly = PathHeaderLabel.pair(
        leftPath: "/tmp/a.txt",
        rightPath: nil,
        maxCharactersPerSide: 40
    )
    #expect(leftOnly.left.contains("a.txt"))
    #expect(leftOnly.right == "Right")
}

@Test func pathHeaderLabelShowsSameLabelForIdenticalPaths() {
    let path = "/Users/me/proj/src/Main.swift"
    let pair = PathHeaderLabel.pair(leftPath: path, rightPath: path, maxCharactersPerSide: 80)
    #expect(pair.left == pair.right)
    #expect(pair.left == "/Users/me/proj/src/Main.swift")
}

@Test func pathHeaderLabelKeepsCommonPrefixWhenWidthAllows() {
    let left = "/Users/me/work/project/src/Main.swift"
    let right = "/Users/me/work/backup/src/Main.swift"
    let pair = PathHeaderLabel.pair(leftPath: left, rightPath: right, maxCharactersPerSide: 80)

    #expect(pair.left != pair.right)
    #expect(pair.left == "/Users/me/work/project/src/Main.swift")
    #expect(pair.right == "/Users/me/work/backup/src/Main.swift")
}

@Test func pathHeaderLabelStripsCommonPrefixOnlyWhenNeededForWidth() {
    let left = "/Users/me/work/project/src/Main.swift"
    let right = "/Users/me/work/backup/src/Main.swift"
    let pair = PathHeaderLabel.pair(leftPath: left, rightPath: right, maxCharactersPerSide: 24)

    #expect(pair.left != pair.right)
    #expect(pair.left.hasSuffix("Main.swift"))
    #expect(pair.right.hasSuffix("Main.swift"))
    #expect(pair.left.contains("project"))
    #expect(pair.right.contains("backup"))
    #expect(!pair.left.contains("Users/me/work/project/src/Main.swift"))
    #expect(pair.left.count <= 24)
    #expect(pair.right.count <= 24)
}

@Test func pathHeaderLabelKeepsFileNameWhenDirectoryIsTruncated() {
    let left = "/very/long/directory/structure/project/src/UniqueLeft.swift"
    let right = "/very/long/directory/structure/backup/src/UniqueRight.swift"
    let pair = PathHeaderLabel.pair(leftPath: left, rightPath: right, maxCharactersPerSide: 28)

    #expect(pair.left != pair.right)
    #expect(pair.left.hasSuffix("UniqueLeft.swift") || pair.left.contains("UniqueLeft.swift"))
    #expect(pair.right.hasSuffix("UniqueRight.swift") || pair.right.contains("UniqueRight.swift"))
    #expect(pair.left.count <= 28)
    #expect(pair.right.count <= 28)
}

@Test func pathHeaderLabelMayTruncateFileNameOnlyWhenExtremelyNarrow() {
    let left = "/a/project/VeryLongFileName.swift"
    let right = "/b/backup/VeryLongFileName.swift"
    let pair = PathHeaderLabel.pair(leftPath: left, rightPath: right, maxCharactersPerSide: 8)

    #expect(pair.left.count <= 8)
    #expect(pair.right.count <= 8)
}

@Test func pathHeaderLabelShowsFullRelativeBasesWhenWideEnough() {
    let left = "/tmp/left/a.txt"
    let right = "/tmp/right/a.txt"
    let pair = PathHeaderLabel.pair(leftPath: left, rightPath: right, maxCharactersPerSide: 200)

    #expect(pair.left == "/tmp/left/a.txt")
    #expect(pair.right == "/tmp/right/a.txt")
}
