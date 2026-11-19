import AppKit
import SwiftUI

/// Scrollable, read-only RTF viewer for a resource in the app bundle.
struct BundledRTFView: NSViewRepresentable {
    let resourceName: String
    let fileExtension: String
    let missingMessage: String

    @Environment(\.colorScheme) private var colorScheme

    init(
        resourceName: String,
        fileExtension: String = "rtf",
        missingMessage: String
    ) {
        self.resourceName = resourceName
        self.fileExtension = fileExtension
        self.missingMessage = missingMessage
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)

        if let attributed = Self.loadAttributedString(
            resourceName: resourceName,
            fileExtension: fileExtension
        ) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = missingMessage
        }

        Self.applyAdaptiveColors(to: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        _ = colorScheme
        Self.applyAdaptiveColors(to: textView)
    }

    private static func applyAdaptiveColors(to textView: NSTextView) {
        textView.textColor = .labelColor
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.addAttribute(
            .foregroundColor,
            value: NSColor.labelColor,
            range: NSRange(location: 0, length: storage.length)
        )
    }

    static func loadAttributedString(
        resourceName: String,
        fileExtension: String,
        bundle: Bundle = .main
    ) -> NSAttributedString? {
        guard let url = bundle.url(forResource: resourceName, withExtension: fileExtension) else {
            return nil
        }
        return try? NSAttributedString(
            url: url,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
}
