import Foundation

/// Builds compact left/right path labels for the compare session header.
public enum PathHeaderLabel {
    public struct Pair: Sendable, Equatable {
        public let left: String
        public let right: String

        public init(left: String, right: String) {
            self.left = left
            self.right = right
        }
    }

    /// Returns display labels constrained to roughly `maxCharactersPerSide` characters each.
    ///
    /// When both full paths fit, the common prefix is kept. Common-prefix stripping is used
    /// only as a fallback when width is insufficient.
    public static func pair(
        leftPath: String?,
        rightPath: String?,
        maxCharactersPerSide: Int
    ) -> Pair {
        let maxChars = max(maxCharactersPerSide, 1)
        switch (leftPath, rightPath) {
        case (nil, nil):
            return Pair(left: "Left", right: "Right")
        case let (left?, nil):
            return Pair(left: fit(left, maxCharacters: maxChars), right: "Right")
        case let (nil, right?):
            return Pair(left: "Left", right: fit(right, maxCharacters: maxChars))
        case let (left?, right?):
            if left == right {
                let label = fit(left, maxCharacters: maxChars)
                return Pair(left: label, right: label)
            }

            if left.count <= maxChars, right.count <= maxChars {
                return Pair(left: left, right: right)
            }

            let (leftBase, rightBase) = distinguishingBases(left: left, right: right)
            return Pair(
                left: fit(leftBase, maxCharacters: maxChars),
                right: fit(rightBase, maxCharacters: maxChars)
            )
        }
    }

    /// Drops the longest common directory prefix so the two labels differ when paths differ.
    private static func distinguishingBases(left: String, right: String) -> (String, String) {
        let leftComponents = pathComponents(left)
        let rightComponents = pathComponents(right)
        let shared = commonPrefixCount(leftComponents, rightComponents)

        let leftSuffix = Array(leftComponents.dropFirst(shared))
        let rightSuffix = Array(rightComponents.dropFirst(shared))

        let leftParts = leftSuffix.isEmpty ? Array(leftComponents.suffix(1)) : leftSuffix
        let rightParts = rightSuffix.isEmpty ? Array(rightComponents.suffix(1)) : rightSuffix

        return (leftParts.joined(separator: "/"), rightParts.joined(separator: "/"))
    }

    private static func pathComponents(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private static func commonPrefixCount(_ lhs: [String], _ rhs: [String]) -> Int {
        let limit = min(lhs.count, rhs.count)
        var index = 0
        while index < limit, lhs[index] == rhs[index] {
            index += 1
        }
        if index == limit, lhs.count == rhs.count, index > 0 {
            return index - 1
        }
        return index
    }

    /// Fits `label` into `maxCharacters`, preferring to keep the filename intact.
    private static func fit(_ label: String, maxCharacters: Int) -> String {
        guard label.count > maxCharacters else {
            return label
        }

        let fileName = (label as NSString).lastPathComponent
        if fileName.count >= maxCharacters {
            return truncateEnd(fileName, maxCharacters: maxCharacters)
        }

        let ellipsis = "…/"
        let budgetForDirectory = maxCharacters - fileName.count - 1
        if budgetForDirectory <= ellipsis.count {
            if fileName.count <= maxCharacters {
                return fileName
            }
            return truncateEnd(fileName, maxCharacters: maxCharacters)
        }

        let directory = (label as NSString).deletingLastPathComponent
        guard !directory.isEmpty, directory != label else {
            return truncateEnd(fileName, maxCharacters: maxCharacters)
        }

        let directoryBudget = budgetForDirectory - ellipsis.count
        if directoryBudget <= 0 {
            return fileName.count <= maxCharacters ? fileName : truncateEnd(fileName, maxCharacters: maxCharacters)
        }

        if directory.count <= directoryBudget {
            let candidate = "\(directory)/\(fileName)"
            if candidate.count <= maxCharacters {
                return candidate
            }
        }

        let suffix = String(directory.suffix(directoryBudget))
        let candidate = "\(ellipsis)\(suffix)/\(fileName)"
        if candidate.count <= maxCharacters {
            return candidate
        }
        return truncateEnd(fileName, maxCharacters: maxCharacters)
    }

    private static func truncateEnd(_ string: String, maxCharacters: Int) -> String {
        guard string.count > maxCharacters else {
            return string
        }
        if maxCharacters <= 1 {
            return "…"
        }
        let keep = maxCharacters - 1
        return "…" + String(string.suffix(keep))
    }
}
