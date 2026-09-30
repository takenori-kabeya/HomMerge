import Foundation

enum FolderCompareTableColumnID: String, CaseIterable {
    case name
    case status
    case leftDate
    case rightDate
    case path
}

enum FolderCompareTablePreferences {
    static let columnWidthsKey = "folderCompare.columnWidths"

    static func defaultWidth(for id: FolderCompareTableColumnID) -> CGFloat {
        switch id {
        case .name: return 250
        case .status: return 70
        case .leftDate, .rightDate: return 140
        case .path: return 200
        }
    }

    static func minimumWidth(for id: FolderCompareTableColumnID) -> CGFloat {
        switch id {
        case .name: return 120
        case .status: return 40
        case .leftDate, .rightDate: return 110
        case .path: return 80
        }
    }

    static func maximumWidth(for id: FolderCompareTableColumnID) -> CGFloat? {
        switch id {
        case .status: return 100
        case .leftDate, .rightDate: return 160
        case .name, .path: return nil
        }
    }

    static func clampedWidth(_ raw: CGFloat, for id: FolderCompareTableColumnID) -> CGFloat {
        let lower = max(raw, minimumWidth(for: id))
        guard let maximum = maximumWidth(for: id) else {
            return lower
        }
        return min(lower, maximum)
    }

    static func load(defaults: UserDefaults = .standard) -> [FolderCompareTableColumnID: CGFloat] {
        let stored = defaults.dictionary(forKey: columnWidthsKey) ?? [:]
        var widths: [FolderCompareTableColumnID: CGFloat] = [:]
        for id in FolderCompareTableColumnID.allCases {
            if let number = stored[id.rawValue] as? NSNumber {
                widths[id] = clampedWidth(CGFloat(truncating: number), for: id)
            } else {
                widths[id] = defaultWidth(for: id)
            }
        }
        return widths
    }

    static func save(
        _ widths: [FolderCompareTableColumnID: CGFloat],
        defaults: UserDefaults = .standard
    ) {
        var payload: [String: Double] = [:]
        for id in FolderCompareTableColumnID.allCases {
            let raw = widths[id] ?? defaultWidth(for: id)
            payload[id.rawValue] = Double(clampedWidth(raw, for: id))
        }
        defaults.set(payload, forKey: columnWidthsKey)
    }
}
