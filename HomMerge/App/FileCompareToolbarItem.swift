import SwiftUI

/// Actions shown on the file-compare result toolbar.
enum FileCompareToolbarItem: String, CaseIterable, Sendable {
    case copyRight
    case copyLeft
    case copyRightAndNext
    case copyLeftAndNext
    case refresh
    case firstDiff
    case previousDiff
    case currentDiff
    case nearestDiff
    case nextDiff
    case lastDiff

    var title: String {
        switch self {
        case .copyRight: return String(localized: "Copy →")
        case .copyLeft: return String(localized: "← Copy")
        case .copyRightAndNext: return String(localized: "Copy → and Next")
        case .copyLeftAndNext: return String(localized: "← Copy and Next")
        case .refresh: return String(localized: "Refresh")
        case .firstDiff: return String(localized: "First Diff")
        case .previousDiff: return String(localized: "Previous Diff")
        case .currentDiff: return String(localized: "Current Diff")
        case .nearestDiff: return String(localized: "Nearest Diff")
        case .nextDiff: return String(localized: "Next Diff")
        case .lastDiff: return String(localized: "Last Diff")
        }
    }

    var systemImages: [String] {
        switch self {
        case .copyRight: return ["arrow.right"]
        case .copyLeft: return ["arrow.left"]
        case .copyRightAndNext: return ["arrow.right", "chevron.down"]
        case .copyLeftAndNext: return ["arrow.left", "chevron.down"]
        case .refresh: return ["arrow.clockwise"]
        case .firstDiff: return ["chevron.up.2"]
        case .previousDiff: return ["chevron.up"]
        case .currentDiff: return ["scope"]
        case .nearestDiff: return ["text.cursor", "scope"]
        case .nextDiff: return ["chevron.down"]
        case .lastDiff: return ["chevron.down.2"]
        }
    }

    var help: String {
        switch self {
        case .copyRight:
            return String(localized: "Copy current difference to the right")
        case .copyLeft:
            return String(localized: "Copy current difference to the left")
        case .copyRightAndNext:
            return String(localized: "Copy current difference to the right and go to the next difference")
        case .copyLeftAndNext:
            return String(localized: "Copy current difference to the left and go to the next difference")
        case .refresh:
            return String(localized: "Reload both files from disk")
        case .firstDiff:
            return String(localized: "Go to the first difference")
        case .previousDiff:
            return String(localized: "Go to the previous difference")
        case .currentDiff:
            return String(localized: "Scroll to the current difference")
        case .nearestDiff:
            return String(localized: "Select the difference nearest to the caret")
        case .nextDiff:
            return String(localized: "Go to the next difference")
        case .lastDiff:
            return String(localized: "Go to the last difference")
        }
    }
}

enum FileCompareToolbarPreferences {
    static let usesIconsKey = "fileCompareToolbarUsesIcons"
}

/// Shared icon-cluster metrics so toolbar buttons share one height in Icons mode.
private enum ToolbarIconCluster {
    static let height: CGFloat = 16

    @ViewBuilder
    static func label(systemImages: [String]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(systemImages.enumerated()), id: \.offset) { _, name in
                Image(systemName: name)
            }
        }
        .font(.body)
        .imageScale(.medium)
        .frame(height: height, alignment: .center)
        .contentShape(Rectangle())
    }
}

/// Actions shown on the session top toolbar (Open / Compare / Save).
enum SessionToolbarItem: String, CaseIterable, Sendable {
    case openLeft
    case openRight
    case compare
    case saveLeft
    case saveRight

    var title: String {
        switch self {
        case .openLeft: return String(localized: "Open Left…")
        case .openRight: return String(localized: "Open Right…")
        case .compare: return String(localized: "Compare")
        case .saveLeft: return String(localized: "Save Left")
        case .saveRight: return String(localized: "Save Right")
        }
    }

    var systemImages: [String] {
        switch self {
        case .openLeft: return ["arrow.left", "folder"]
        case .openRight: return ["folder", "arrow.right"]
        case .compare: return ["arrow.left.arrow.right"]
        case .saveLeft: return ["arrow.left", "square.and.arrow.down"]
        case .saveRight: return ["square.and.arrow.down", "arrow.right"]
        }
    }

    var help: String { title }
}

/// Actions shown on the folder-compare result toolbar.
enum FolderCompareToolbarItem: String, CaseIterable, Sendable {
    case compareSelectedFiles
    case copyRight
    case copyLeft
    case delete
    case refresh

    var title: String {
        switch self {
        case .compareSelectedFiles: return String(localized: "Compare Selected Files")
        case .copyRight: return String(localized: "Copy →")
        case .copyLeft: return String(localized: "← Copy")
        case .delete: return String(localized: "Delete")
        case .refresh: return String(localized: "Refresh")
        }
    }

    var systemImages: [String] {
        switch self {
        case .compareSelectedFiles: return ["doc.on.doc", "arrow.left.arrow.right"]
        case .copyRight: return ["arrow.right"]
        case .copyLeft: return ["arrow.left"]
        case .delete: return ["trash"]
        case .refresh: return ["arrow.clockwise"]
        }
    }

    var help: String {
        switch self {
        case .compareSelectedFiles: return String(localized: "Compare Selected Files")
        case .copyRight: return String(localized: "Copy selected item to the right folder")
        case .copyLeft: return String(localized: "Copy selected item to the left folder")
        case .delete: return String(localized: "Move selected left-only or right-only files to the Trash")
        case .refresh: return String(localized: "Rescan both folders from disk")
        }
    }
}

/// Text or SF Symbol button for a file-compare toolbar action.
struct FileCompareToolbarButton: View {
    let item: FileCompareToolbarItem
    let useIcons: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if useIcons {
                ToolbarIconCluster.label(systemImages: item.systemImages)
            } else {
                Text(item.title)
            }
        }
        .disabled(!isEnabled)
        .help(item.help)
    }
}

/// Text or one-or-more SF Symbol button for session / folder toolbar actions.
struct MultiSymbolToolbarButton: View {
    let title: String
    let systemImages: [String]
    let useIcons: Bool
    var isEnabled: Bool = true
    let help: String
    let action: () -> Void

    init(
        item: SessionToolbarItem,
        useIcons: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = item.title
        self.systemImages = item.systemImages
        self.useIcons = useIcons
        self.isEnabled = isEnabled
        self.help = item.help
        self.action = action
    }

    init(
        item: FolderCompareToolbarItem,
        useIcons: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = item.title
        self.systemImages = item.systemImages
        self.useIcons = useIcons
        self.isEnabled = isEnabled
        self.help = item.help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if useIcons {
                ToolbarIconCluster.label(systemImages: systemImages)
            } else {
                Text(title)
            }
        }
        .disabled(!isEnabled)
        .help(help)
    }
}
