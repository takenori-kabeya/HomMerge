/// Myers shortest-edit-script diff over equatable sequences.
enum MyersDiffer {
    enum Edit: Equatable {
        case insert(bIndex: Int)
        case delete(aIndex: Int)
        case equal(aIndex: Int, bIndex: Int)
    }

    static func diff<Element: Equatable>(_ a: [Element], _ b: [Element]) -> [Edit] {
        let n = a.count
        let m = b.count
        let maxD = n + m

        if n == 0 && m == 0 {
            return []
        }
        if n == 0 {
            return (0..<m).map { .insert(bIndex: $0) }
        }
        if m == 0 {
            return (0..<n).map { .delete(aIndex: $0) }
        }

        var v = Array(repeating: 0, count: 2 * maxD + 1)
        var trace: [[Int]] = []
        var finishedD = 0

        outer: for d in 0...maxD {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                let offset = k + maxD
                var x: Int
                if k == -d || (k != d && v[offset - 1] < v[offset + 1]) {
                    x = v[offset + 1]
                } else {
                    x = v[offset - 1] + 1
                }
                var y = x - k
                while x < n, y < m, a[x] == b[y] {
                    x += 1
                    y += 1
                }
                v[offset] = x
                if x >= n, y >= m {
                    finishedD = d
                    break outer
                }
            }
        }

        return backtrack(aCount: n, bCount: m, maxD: maxD, trace: trace, d: finishedD)
    }

    private static func backtrack(
        aCount n: Int,
        bCount m: Int,
        maxD: Int,
        trace: [[Int]],
        d: Int
    ) -> [Edit] {
        var edits: [Edit] = []
        var x = n
        var y = m

        for depth in stride(from: d, through: 0, by: -1) {
            let v = trace[depth]
            let k = x - y
            let offset = k + maxD

            let prevK: Int
            if k == -depth || (k != depth && v[offset - 1] < v[offset + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX = v[prevK + maxD]
            let prevY = prevX - prevK

            while x > prevX, y > prevY {
                x -= 1
                y -= 1
                edits.append(.equal(aIndex: x, bIndex: y))
            }

            if depth == 0 {
                break
            }

            if x == prevX {
                y -= 1
                edits.append(.insert(bIndex: y))
            } else {
                x -= 1
                edits.append(.delete(aIndex: x))
            }
        }

        return edits.reversed()
    }
}
