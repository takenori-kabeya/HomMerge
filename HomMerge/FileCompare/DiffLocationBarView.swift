import AppKit
import DiffEngine

/// Fixed viewport map of diff hunks between the left and right panes.
@MainActor
final class DiffLocationBarView: NSView {
    var hunks: [DiffHunk] = [] {
        didSet { needsDisplay = true }
    }

    var totalRows: Int = 0 {
        didSet { needsDisplay = true }
    }

    var currentHunkIndex: Int? {
        didSet { needsDisplay = true }
    }

    var visibleViewport: DiffLocationViewportFrame? {
        didSet { needsDisplay = true }
    }

    var onSelectHunk: ((Int) -> Void)?

    private let minimumBlockHeight: CGFloat = 4

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        if let visibleViewport {
            let viewportRect = NSRect(
                x: 3,
                y: visibleViewport.originY,
                width: max(bounds.width - 6, 2),
                height: visibleViewport.height
            )
            NSColor.separatorColor.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: viewportRect).fill()
            NSColor.tertiaryLabelColor.setStroke()
            let viewportBorder = NSBezierPath(rect: viewportRect.insetBy(dx: 0.5, dy: 0.5))
            viewportBorder.lineWidth = 1
            viewportBorder.stroke()
        }

        let frames = DiffLocationLayout.blockFrames(
            hunks: hunks,
            totalRows: totalRows,
            barHeight: Double(bounds.height),
            minimumBlockHeight: Double(minimumBlockHeight)
        )

        for frame in frames {
            let rect = NSRect(
                x: 3,
                y: frame.originY,
                width: max(bounds.width - 6, 2),
                height: frame.height
            )
            let isCurrent = frame.hunkIndex == currentHunkIndex
            let fill = isCurrent
                ? DiffHighlightStyle.currentHunkBarFill
                : NSColor.systemOrange.withAlphaComponent(0.55)
            fill.setFill()
            let path = NSBezierPath(
                roundedRect: rect,
                xRadius: 2,
                yRadius: 2
            )
            path.fill()

            if isCurrent {
                DiffHighlightStyle.currentHunkBarStroke.setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let frames = DiffLocationLayout.blockFrames(
            hunks: hunks,
            totalRows: totalRows,
            barHeight: Double(bounds.height),
            minimumBlockHeight: Double(minimumBlockHeight)
        )
        guard let index = DiffLocationLayout.hunkIndex(nearestToY: Double(point.y), in: frames) else {
            return
        }
        onSelectHunk?(index)
    }
}
