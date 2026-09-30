import Foundation

/// A left/right path pair passed on the command line at application launch.
struct LaunchComparisonRequest: Equatable, Sendable {
    let left: URL
    let right: URL
}

enum LaunchArgumentsParser {
    private static let leftFlag = "--left"
    private static let rightFlag = "--right"

    /// Parses two file paths received via Launch Services (no executable prefix).
    static func parseOpenFiles(_ paths: [String]) -> LaunchComparisonRequest? {
        guard paths.count == 2 else {
            return nil
        }
        return makeRequest(leftPath: paths[0], rightPath: paths[1])
    }

    /// Parses launch arguments into a comparison request, or `nil` for a normal GUI launch.
    static func parse(_ arguments: [String]) -> LaunchComparisonRequest? {
        let tokens = stripInternalArguments(from: Array(arguments.dropFirst()))
        guard !tokens.isEmpty else {
            return nil
        }

        if let leftPath = value(for: leftFlag, in: tokens),
           let rightPath = value(for: rightFlag, in: tokens)
        {
            return makeRequest(leftPath: leftPath, rightPath: rightPath)
        }

        let positional = tokens.filter { !$0.hasPrefix("-") }
        guard positional.count == 2 else {
            return nil
        }
        return makeRequest(leftPath: positional[0], rightPath: positional[1])
    }

    /// Returns whether CLI arguments use `--left` / `--right` flags (not positional paths).
    static func isFlagBasedComparison(_ arguments: [String]) -> Bool {
        let tokens = stripInternalArguments(from: Array(arguments.dropFirst()))
        return value(for: leftFlag, in: tokens) != nil && value(for: rightFlag, in: tokens) != nil
    }

    private static func stripInternalArguments(from tokens: [String]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if isInternalArgument(token) {
                index += 1
                if takesFollowingValue(token), index < tokens.count {
                    index += 1
                }
                continue
            }
            result.append(token)
            index += 1
        }
        return result
    }

    private static func value(for flag: String, in tokens: [String]) -> String? {
        for (index, token) in tokens.enumerated() {
            if token == flag {
                guard index + 1 < tokens.count else {
                    return nil
                }
                let value = tokens[index + 1]
                guard !value.hasPrefix("-") else {
                    return nil
                }
                return value
            }
            if token.hasPrefix("\(flag)=") {
                let value = String(token.dropFirst(flag.count + 1))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    private static func isInternalArgument(_ token: String) -> Bool {
        token.hasPrefix("-NS") || token == "-AppleLanguages" || token == "-AppleLocale"
    }

    private static func takesFollowingValue(_ token: String) -> Bool {
        token == "-AppleLanguages" || token == "-AppleLocale" || token == "-NSDocumentRevisionsDebugMode"
    }

    private static func makeRequest(leftPath: String, rightPath: String) -> LaunchComparisonRequest? {
        guard let left = normalizedURL(for: leftPath),
              let right = normalizedURL(for: rightPath)
        else {
            return nil
        }
        return LaunchComparisonRequest(left: left, right: right)
    }

    private static func normalizedURL(for path: String) -> URL? {
        let expanded = (path as NSString).expandingTildeInPath
        guard !expanded.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: expanded, isDirectory: false).standardizedFileURL
    }
}
