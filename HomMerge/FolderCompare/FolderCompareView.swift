import DiffEngine
import SwiftUI

/// Result UI for a folder-to-folder compare (paths are owned by `CompareSessionViewModel`).
struct FolderCompareView: View {
    @Bindable var viewModel: FolderCompareViewModel
    let onOpenFileCompare: (URL, URL) -> Void
    @AppStorage(FileCompareToolbarPreferences.usesIconsKey) private var useIconToolbar = false

    private static let modificationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            MultiSymbolToolbarButton(
                item: .compareSelectedFiles,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canOpenSelectedFileCompare,
                action: openSelected
            )

            MultiSymbolToolbarButton(
                item: .copyRight,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canCopyToRight,
                action: viewModel.copySelectedToRight
            )

            MultiSymbolToolbarButton(
                item: .copyLeft,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canCopyToLeft,
                action: viewModel.copySelectedToLeft
            )

            MultiSymbolToolbarButton(
                item: .delete,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canDeleteSelected,
                action: viewModel.deleteSelected
            )

            MultiSymbolToolbarButton(
                item: .refresh,
                useIcons: useIconToolbar,
                action: viewModel.refresh
            )

            Spacer()

            Toggle("Show Only Differences", isOn: $viewModel.showOnlyDifferences)
                .toggleStyle(.checkbox)
            Toggle("Exclude Hidden", isOn: $viewModel.excludeHidden)
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.hasResult {
            Table(
                viewModel.displayedEntries,
                children: \.childrenOrNil,
                selection: $viewModel.selectedEntryIDs
            ) {
                TableColumn("Name") { entry in
                    Label(entry.name, systemImage: iconName(for: entry))
                        .foregroundStyle(color(for: entry.status))
                }
                .width(min: 120, ideal: 250)
                .customizationID(FolderCompareTableColumnID.name.rawValue)
                TableColumn("Status") { entry in
                    Text(statusLabel(for: entry.status))
                        .foregroundStyle(color(for: entry.status))
                }
                .width(min: 40, ideal: 70, max: 100)
                .customizationID(FolderCompareTableColumnID.status.rawValue)
                TableColumn("Left Date") { entry in
                    modificationDateCell(
                        entry.leftModificationDate,
                        highlight: entry.newerModificationSide == .left
                    )
                }
                .width(min: 110, ideal: 140, max: 160)
                .customizationID(FolderCompareTableColumnID.leftDate.rawValue)
                TableColumn("Right Date") { entry in
                    modificationDateCell(
                        entry.rightModificationDate,
                        highlight: entry.newerModificationSide == .right
                    )
                }
                .width(min: 110, ideal: 140, max: 160)
                .customizationID(FolderCompareTableColumnID.rightDate.rawValue)
                TableColumn("Path") { entry in
                    Text(entry.relativePath)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 200)
                .customizationID(FolderCompareTableColumnID.path.rawValue)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .background(FolderCompareTableWidthSync())
            .contextMenu(forSelectionType: FolderEntry.ID.self) { ids in
                let selected = entries(for: ids)
                let crossOptions = FolderCompareSelection.crossFileCompareOptions(entries: selected)
                if !crossOptions.isEmpty {
                    ForEach(crossOptions) { option in
                        Button(option.title) {
                            openCrossFileCompare(option, selectionIDs: ids)
                        }
                        .disabled(!option.isEnabled)
                    }
                    Divider()
                }

                Button("Compare Files") {
                    openEntries(ids)
                }
                .disabled(!canOpen(ids))

                Divider()

                Button("Copy to Right") {
                    copyEntries(ids, toRight: true)
                }
                .disabled(!canCopy(ids, toRight: true))

                Button("Copy to Left") {
                    copyEntries(ids, toRight: false)
                }
                .disabled(!canCopy(ids, toRight: false))

                Divider()

                Button("Move to Trash") {
                    deleteEntries(ids)
                }
                .disabled(!canDelete(ids))
            } primaryAction: { ids in
                openEntries(ids)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        } else {
            Text(viewModel.statusText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
    }

    private func modificationDateCell(_ date: Date?, highlight: Bool) -> some View {
        HStack(spacing: 2) {
            Text(highlight ? "🆕" : " ")
                .frame(width: 16, alignment: .center)
            if let date {
                Text(Self.modificationDateFormatter.string(from: date))
                    .monospacedDigit()
            }
        }
    }

    private func openSelected() {
        viewModel.openSelectedFileCompares(onOpen: onOpenFileCompare)
    }

    private func entries(for ids: Set<FolderEntry.ID>) -> [FolderEntry] {
        ids
            .compactMap { viewModel.entry(withID: $0) }
            .sorted { $0.relativePath < $1.relativePath }
    }

    private func canOpen(_ ids: Set<FolderEntry.ID>) -> Bool {
        FolderCompareSelection.canCompare(entries: entries(for: ids))
    }

    private func canCopy(_ ids: Set<FolderEntry.ID>, toRight: Bool) -> Bool {
        let selected = entries(for: ids)
        if toRight {
            return FolderCompareSelection.canCopy(
                entries: selected,
                sourceSide: .left,
                destinationRootPath: viewModel.rightPath
            )
        }
        return FolderCompareSelection.canCopy(
            entries: selected,
            sourceSide: .right,
            destinationRootPath: viewModel.leftPath
        )
    }

    private func canDelete(_ ids: Set<FolderEntry.ID>) -> Bool {
        FolderCompareSelection.canDelete(entries: entries(for: ids))
    }

    private func copyEntries(_ ids: Set<FolderEntry.ID>, toRight: Bool) {
        viewModel.selectedEntryIDs = ids
        if toRight {
            viewModel.copySelectedToRight()
        } else {
            viewModel.copySelectedToLeft()
        }
    }

    private func deleteEntries(_ ids: Set<FolderEntry.ID>) {
        viewModel.selectedEntryIDs = ids
        viewModel.deleteSelected()
    }

    private func openEntries(_ ids: Set<FolderEntry.ID>) {
        viewModel.selectedEntryIDs = ids
        viewModel.openSelectedFileCompares(onOpen: onOpenFileCompare)
    }

    private func openCrossFileCompare(_ option: CrossFileCompareOption, selectionIDs: Set<FolderEntry.ID>) {
        guard option.isEnabled, let left = option.leftURL, let right = option.rightURL else {
            return
        }
        viewModel.selectedEntryIDs = selectionIDs
        viewModel.openCrossFileCompare(left: left, right: right, onOpen: onOpenFileCompare)
    }

    private func iconName(for entry: FolderEntry) -> String {
        entry.kind == .directory ? "folder" : "doc.text"
    }

    private func statusLabel(for status: FolderEntryStatus) -> String {
        switch status {
        case .identical: return "Identical"
        case .different: return "Different"
        case .leftOnly: return "Left only"
        case .rightOnly: return "Right only"
        }
    }

    private func color(for status: FolderEntryStatus) -> Color {
        switch status {
        case .identical: return .secondary
        case .different: return .orange
        case .leftOnly: return .red
        case .rightOnly: return .green
        }
    }
}

private extension FolderEntry {
    var childrenOrNil: [FolderEntry]? {
        kind == .directory ? children : nil
    }
}
