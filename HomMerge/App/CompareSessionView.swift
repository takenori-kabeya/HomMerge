import AppKit
import DiffEngine
import SwiftUI
import UniformTypeIdentifiers

struct CompareSessionView: View {
    @Bindable var session: CompareSessionViewModel
    let onOpenFileCompare: (URL, URL) -> Void

    @State private var pathHeaderWidth: CGFloat = 10_000
    @AppStorage(FileCompareToolbarPreferences.usesIconsKey) private var useIconToolbar = false

    var body: some View {
        VStack(spacing: 0) {
            sessionToolbar
            Divider()
            pathHeader
            Divider()
            resultContent
            Divider()
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionToolbar: some View {
        HStack(spacing: 10) {
            MultiSymbolToolbarButton(
                item: .openLeft,
                useIcons: useIconToolbar,
                action: session.openLeft
            )
            MultiSymbolToolbarButton(
                item: .openRight,
                useIcons: useIconToolbar,
                action: session.openRight
            )

            MultiSymbolToolbarButton(
                item: .compare,
                useIcons: useIconToolbar,
                isEnabled: session.canCompare,
                action: session.compare
            )

            Divider().frame(height: 16)

            MultiSymbolToolbarButton(
                item: .saveLeft,
                useIcons: useIconToolbar,
                isEnabled: session.fileCompare?.canSaveLeft ?? false
            ) {
                session.fileCompare?.saveLeft()
            }

            MultiSymbolToolbarButton(
                item: .saveRight,
                useIcons: useIconToolbar,
                isEnabled: session.fileCompare?.canSaveRight ?? false
            ) {
                session.fileCompare?.saveRight()
            }

            Spacer()

            Picker("Toolbar labels", selection: $useIconToolbar) {
                Text("Text").tag(false)
                Text("Icons").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)
            .help("Show toolbar actions as text or icons")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var pathHeader: some View {
        let sideWidth = max((pathHeaderWidth - 1) / 2, 1)
        // Headline ~11–13pt; use a slightly optimistic estimate so we don't over-truncate.
        let maxCharacters = max(Int(sideWidth / 6.5), 8)
        let labels = PathHeaderLabel.pair(
            leftPath: session.leftURL?.path,
            rightPath: session.rightURL?.path,
            maxCharactersPerSide: maxCharacters
        )

        return HStack(spacing: 0) {
            pathLabel(
                title: labels.left,
                fullPath: session.leftURL?.path,
                side: .left
            )
            Divider()
            pathLabel(
                title: labels.right,
                fullPath: session.rightURL?.path,
                side: .right
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: PathHeaderWidthPreferenceKey.self, value: geometry.size.width)
            }
        }
        .onPreferenceChange(PathHeaderWidthPreferenceKey.self) { width in
            if width > 1 {
                pathHeaderWidth = width
            }
        }
    }

    private func pathLabel(title: String, fullPath: String?, side: DiffPaneSide) -> some View {
        HStack(spacing: 4) {
            Button {
                session.clearPath(side: side)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(fullPath == nil)
            .help("Close")

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(fullPath ?? title)

            Menu {
                Button("Copy Path") {
                    guard let fullPath else { return }
                    copyPathToPasteboard(fullPath)
                }
                Button("Create Backup File") {
                    guard let fullPath else { return }
                    createBackupFile(atPath: fullPath)
                }
                .disabled(!canCreateBackup(atPath: fullPath))
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(fullPath == nil)
            .help("Path Actions")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers, side: side)
        }
    }

    private func copyPathToPasteboard(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }

    private func canCreateBackup(atPath path: String?) -> Bool {
        guard let path else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }

    private func createBackupFile(atPath path: String) {
        let source = URL(fileURLWithPath: path)
        let destination = source.appendingPathExtension("bak")
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not create backup file"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch session.phase {
        case .idle:
            placeholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        case .files(let viewModel):
            FileCompareView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        case .folders(let viewModel):
            FolderCompareView(viewModel: viewModel, onOpenFileCompare: onOpenFileCompare)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .font(.title3)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text("Drop files or folders here, then press Compare")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                dropZone(title: "Left", side: .left)
                dropZone(title: "Right", side: .right)
            }
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func dropZone(title: String, side: DiffPaneSide) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            .foregroundStyle(.secondary)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .overlay {
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 140)
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, side: side)
            }
    }

    private var statusBar: some View {
        Text(session.statusText)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private func handleDrop(providers: [NSItemProvider], side: DiffPaneSide) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let fileURL = item as? URL {
                url = fileURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in
                session.setPath(url, side: side)
            }
        }
        return true
    }
}

private struct PathHeaderWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
