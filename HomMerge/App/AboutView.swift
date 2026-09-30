import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let icon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("HomMerge")
                        .font(.title2.weight(.semibold))
                    Text("Version \(Bundle.main.shortVersionString) (\(Bundle.main.buildVersionString))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Copyright © 2026 Takenori Kabeya and HomMerge contributors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("End User License Agreement (EULA)")
                .font(.headline)

            EULARTFView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }
}

private struct EULARTFView: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

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

        if let attributed = Self.loadAttributedString() {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = "Could not load EULA.rtf."
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

    private static func loadAttributedString() -> NSAttributedString? {
        guard let url = Bundle.main.url(forResource: "EULA", withExtension: "rtf") else {
            return nil
        }
        return try? NSAttributedString(
            url: url,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    var buildVersionString: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

#Preview {
    AboutView()
}
