import DiffEngine
import Foundation
import Testing

@Test func loadFileDetectsUTF8LF() throws {
    let data = Data("hello\nworld".utf8)
    let loaded = try FileContentLoader.loadFile(data: data)

    #expect(loaded.text == "hello\nworld")
    #expect(loaded.format.encoding == TextEncoding.utf8)
    #expect(loaded.format.lineEnding == LineEndingStyle.lf)
    #expect(loaded.format.includesUTF8BOM == false)
}

@Test func loadFileDetectsUTF8CRLFAndNormalizesLineEndings() throws {
    let data = Data("hello\r\nworld\r\n".utf8)
    let loaded = try FileContentLoader.loadFile(data: data)

    #expect(loaded.text == "hello\nworld\n")
    #expect(loaded.format.lineEnding == LineEndingStyle.crlf)
    #expect(loaded.text.contains("\r") == false)
}

@Test func writePreservesUTF8CRLF() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextFileFormatTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("crlf.txt")
    let format = TextFileFormat(encoding: .utf8, lineEnding: .crlf)
    try FileContentWriter.write("alpha\nbeta\n", format: format, to: url)

    let bytes = try Data(contentsOf: url)
    #expect(bytes == Data("alpha\r\nbeta\r\n".utf8))
}

@Test func shiftJISRoundTripPreservesEncodingAndLineEnding() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextFileFormatTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let original = "日本語\r\nテスト\r\n"
    guard let data = original.data(using: .shiftJIS) else {
        Issue.record("Shift_JIS sample could not be encoded")
        return
    }

    let loaded = try FileContentLoader.loadFile(data: data)
    #expect(loaded.text == "日本語\nテスト\n")
    #expect(loaded.format.encoding == TextEncoding.shiftJIS)
    #expect(loaded.format.lineEnding == LineEndingStyle.crlf)

    let url = directory.appendingPathComponent("shift-jis.txt")
    try FileContentWriter.write(loaded.text, format: loaded.format, to: url)
    #expect(try Data(contentsOf: url) == data)
}

@Test func identicalCRLFAndLFFilesCompareWithoutChanges() throws {
    let left = try FileContentLoader.loadFile(data: Data("alpha\r\nbeta\r\n".utf8))
    let right = try FileContentLoader.loadFile(data: Data("alpha\nbeta\n".utf8))

    var state = FileCompareState()
    state.setLeftText(left.text, format: left.format)
    state.setRightText(right.text, format: right.format)

    #expect(state.hasChanges == false)
}

@Test func crlfAndLFFilesWithContentDifferencesShowHunks() throws {
    let left = try FileContentLoader.loadFile(data: Data("alpha\r\nold\r\n".utf8))
    let right = try FileContentLoader.loadFile(data: Data("alpha\nnew\n".utf8))

    var state = FileCompareState()
    state.setLeftText(left.text, format: left.format)
    state.setRightText(right.text, format: right.format)

    #expect(state.hasChanges == true)
    #expect(state.navigator.hunkCount == 1)
}

@Test func utf8BOMIsDetectedAndPreservedOnWrite() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextFileFormatTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    var data = Data([0xEF, 0xBB, 0xBF])
    data.append(contentsOf: "bom\n".utf8)
    let loaded = try FileContentLoader.loadFile(data: data)
    #expect(loaded.text == "bom\n")
    #expect(loaded.format.includesUTF8BOM == true)

    let url = directory.appendingPathComponent("bom.txt")
    try FileContentWriter.write(loaded.text, format: loaded.format, to: url)
    #expect(try Data(contentsOf: url) == data)
}

@Test func textFileFormatStatusDescriptionIncludesEncodingAndLineEnding() {
    let utf8LF = TextFileFormat(encoding: .utf8, lineEnding: .lf)
    #expect(utf8LF.statusDescription == "UTF-8 · LF")

    let shiftJISCRLF = TextFileFormat(encoding: .shiftJIS, lineEnding: .crlf)
    #expect(shiftJISCRLF.statusDescription == "Shift_JIS · CRLF")

    let utf8BOM = TextFileFormat(encoding: .utf8, lineEnding: .cr, includesUTF8BOM: true)
    #expect(utf8BOM.statusDescription == "UTF-8 BOM · CR")
}

@Test func lineEndingNormalizerRoundTripsCRLF() {
    let original = "a\nb\n"
    let onDisk = LineEndingNormalizer.denormalizeFromLF(original, lineEnding: .crlf)
    #expect(onDisk == "a\r\nb\r\n")
    let normalized = LineEndingNormalizer.normalizeToLF(onDisk, lineEnding: .crlf)
    #expect(normalized == original)
}

@Test func unsupportedEncodingIsRejected() {
    let data = Data([0x30, 0x31, 0x82, 0xA0, 0xFF, 0xFE, 0xFD])
    #expect(throws: FileLoadError.notUTF8) {
        try FileContentLoader.loadFile(data: data)
    }
}
