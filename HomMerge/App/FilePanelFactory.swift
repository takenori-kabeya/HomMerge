import AppKit
import UniformTypeIdentifiers

enum FilePanelFactory {
    static func makeOpenPanel(title: String, canChooseDirectories: Bool) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.item]
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        panel.showsHiddenFiles = true
        return panel
    }

    static func makeSavePanel(title: String) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.title = title
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.showsHiddenFiles = true
        return panel
    }
}
