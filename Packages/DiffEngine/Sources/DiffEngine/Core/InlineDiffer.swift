/// Character-level inline highlight spans for a modified line pair.
///
/// Uses a common-prefix / common-suffix split so highlights stay contiguous and
/// readable (preferring a single replacement over a fragmented Myers SES).
enum InlineDiffer {
    static func diff(_ left: String, _ right: String) -> (left: [InlineSpan], right: [InlineSpan]) {
        let leftChars = Array(left)
        let rightChars = Array(right)

        if leftChars.isEmpty, rightChars.isEmpty {
            return ([], [])
        }
        if leftChars == rightChars {
            let span = InlineSpan(start: 0, end: leftChars.count, kind: .equal)
            return ([span], [span])
        }

        let prefix = commonPrefixLength(leftChars, rightChars)
        let suffix = commonSuffixLength(
            leftChars,
            rightChars,
            excludingPrefix: prefix
        )

        let leftMiddleStart = prefix
        let leftMiddleEnd = leftChars.count - suffix
        let rightMiddleStart = prefix
        let rightMiddleEnd = rightChars.count - suffix

        var leftSpans: [InlineSpan] = []
        var rightSpans: [InlineSpan] = []

        if prefix > 0 {
            leftSpans.append(InlineSpan(start: 0, end: prefix, kind: .equal))
            rightSpans.append(InlineSpan(start: 0, end: prefix, kind: .equal))
        }
        if leftMiddleStart < leftMiddleEnd {
            leftSpans.append(
                InlineSpan(start: leftMiddleStart, end: leftMiddleEnd, kind: .delete)
            )
        }
        if rightMiddleStart < rightMiddleEnd {
            rightSpans.append(
                InlineSpan(start: rightMiddleStart, end: rightMiddleEnd, kind: .insert)
            )
        }
        if suffix > 0 {
            leftSpans.append(
                InlineSpan(
                    start: leftChars.count - suffix,
                    end: leftChars.count,
                    kind: .equal
                )
            )
            rightSpans.append(
                InlineSpan(
                    start: rightChars.count - suffix,
                    end: rightChars.count,
                    kind: .equal
                )
            )
        }

        return (leftSpans, rightSpans)
    }

    private static func commonPrefixLength(_ left: [Character], _ right: [Character]) -> Int {
        let limit = min(left.count, right.count)
        var index = 0
        while index < limit, left[index] == right[index] {
            index += 1
        }
        return index
    }

    private static func commonSuffixLength(
        _ left: [Character],
        _ right: [Character],
        excludingPrefix prefix: Int
    ) -> Int {
        let leftRemain = left.count - prefix
        let rightRemain = right.count - prefix
        let limit = min(leftRemain, rightRemain)
        var index = 0
        while index < limit,
              left[left.count - 1 - index] == right[right.count - 1 - index]
        {
            index += 1
        }
        return index
    }
}
