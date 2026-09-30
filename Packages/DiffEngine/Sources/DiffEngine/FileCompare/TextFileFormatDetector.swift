import Foundation

/// Detects on-disk text encoding and line endings from raw bytes.
public enum TextFileFormatDetector {
    private static let utf8BOM = Data([0xEF, 0xBB, 0xBF])

    public static func detectLineEnding(in data: Data) -> LineEndingStyle {
        guard !data.isEmpty else {
            return .lf
        }
        if data.containsSequence(Data("\r\n".utf8)) {
            return .crlf
        }
        if data.contains(0x0D) {
            return .cr
        }
        return .lf
    }

    public static func decode(data: Data) throws -> LoadedTextFile {
        if FileContentLoader.isBinary(data) {
            throw FileLoadError.binary
        }

        let lineEnding = detectLineEnding(in: data)
        if data.isEmpty {
            return LoadedTextFile(text: "", format: .default)
        }

        var payload = data
        var includesUTF8BOM = false
        if data.starts(with: utf8BOM) {
            includesUTF8BOM = true
            payload = Data(data.dropFirst(utf8BOM.count))
        }

        if let text = String(data: payload, encoding: .utf8) {
            let format = TextFileFormat(
                encoding: .utf8,
                lineEnding: lineEnding,
                includesUTF8BOM: includesUTF8BOM
            )
            let normalized = LineEndingNormalizer.normalizeToLF(text, lineEnding: lineEnding)
            return LoadedTextFile(text: normalized, format: format)
        }

        if let text = String(data: data, encoding: .shiftJIS) {
            let format = TextFileFormat(encoding: .shiftJIS, lineEnding: lineEnding)
            let normalized = LineEndingNormalizer.normalizeToLF(text, lineEnding: lineEnding)
            return LoadedTextFile(text: normalized, format: format)
        }

        throw FileLoadError.notUTF8
    }
}

private extension Data {
    func containsSequence(_ sequence: Data) -> Bool {
        guard !sequence.isEmpty, count >= sequence.count else {
            return false
        }
        var index = startIndex
        while index < endIndex {
            if self[index] == sequence[0] {
                let end = index + sequence.count
                if end <= endIndex, self[index ..< end] == sequence {
                    return true
                }
            }
            index = self.index(after: index)
        }
        return false
    }
}
