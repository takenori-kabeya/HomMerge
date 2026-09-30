import AppKit
import Foundation

enum EditorPreferences {
    static let tabInsertsSpacesKey = "editor.tabInsertsSpaces"
    static let tabWidthKey = "editor.tabWidth"
    static let defaultTabWidth = 4
    static let allowedTabWidths = [2, 4, 8]

    static func clampedTabWidth(_ raw: Int) -> Int {
        if allowedTabWidths.contains(raw) {
            return raw
        }
        return defaultTabWidth
    }

    static func resolvedTabWidth(defaults: UserDefaults = .standard) -> Int {
        clampedTabWidth(defaults.integer(forKey: tabWidthKey))
    }

    /// Display column from line start to caret. Tabs expand to the next stop of `tabWidth`.
    static func displayColumn(linePrefix: String, tabWidth: Int) -> Int {
        let width = max(tabWidth, 1)
        var column = 0
        for character in linePrefix {
            if character == "\t" {
                let remainder = column % width
                column += width - remainder
            } else {
                column += 1
            }
        }
        return column
    }

    static func spacesToNextTabStop(column: Int, tabWidth: Int) -> Int {
        let width = max(tabWidth, 1)
        let remainder = column % width
        return remainder == 0 ? width : width - remainder
    }

    static func insertionString(
        linePrefixBeforeCaret: String,
        defaults: UserDefaults = .standard
    ) -> String {
        guard defaults.bool(forKey: tabInsertsSpacesKey) else {
            return "\t"
        }
        let tabWidth = resolvedTabWidth(defaults: defaults)
        let column = displayColumn(linePrefix: linePrefixBeforeCaret, tabWidth: tabWidth)
        let count = spacesToNextTabStop(column: column, tabWidth: tabWidth)
        return String(repeating: " ", count: count)
    }

    /// Pixel interval for `NSParagraphStyle.defaultTabInterval` (monospace space advance × tab width).
    static func defaultTabInterval(font: NSFont, tabWidth: Int) -> CGFloat {
        let width = max(tabWidth, 1)
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        return spaceWidth * CGFloat(width)
    }

    /// Prefix inserted at the start of each line for multi-line block indent.
    static func lineIndentPrefix(defaults: UserDefaults = .standard) -> String {
        guard defaults.bool(forKey: tabInsertsSpacesKey) else {
            return "\t"
        }
        return String(repeating: " ", count: resolvedTabWidth(defaults: defaults))
    }

    /// UTF-16 length to remove from the start of `line` for one unindent step.
    /// Prefers a leading tab; otherwise removes up to `tabWidth` leading spaces.
    static func leadingUnindentLength(line: String, tabWidth: Int) -> Int {
        let width = max(tabWidth, 1)
        guard let first = line.first else {
            return 0
        }
        if first == "\t" {
            return 1
        }
        var spaceCount = 0
        for character in line {
            guard character == " " else { break }
            spaceCount += 1
            if spaceCount == width {
                break
            }
        }
        return spaceCount
    }
}
