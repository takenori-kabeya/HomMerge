import AppKit

/// Keeps content scroll views vertically aligned and mirrors that offset onto gutter scroll views.
///
/// Observers are delivered on the main queue and update bounds synchronously
/// (no `Task` hop), which keeps left/right scroll positions locked together.
@MainActor
final class SyncScrollCoordinator {
    private weak var leftScrollView: NSScrollView?
    private weak var rightScrollView: NSScrollView?
    private weak var leftGutterScrollView: NSScrollView?
    private weak var rightGutterScrollView: NSScrollView?
    private var isSyncing = false
    /// Tokens are only touched on the main actor or during `deinit` teardown.
    private nonisolated(unsafe) var observations: [NSObjectProtocol] = []

    func attach(
        left: NSScrollView,
        right: NSScrollView,
        leftGutter: NSScrollView? = nil,
        rightGutter: NSScrollView? = nil
    ) {
        if leftScrollView === left,
           rightScrollView === right,
           leftGutterScrollView === leftGutter,
           rightGutterScrollView === rightGutter,
           !observations.isEmpty
        {
            return
        }

        detach()
        leftScrollView = left
        rightScrollView = right
        leftGutterScrollView = leftGutter
        rightGutterScrollView = rightGutter

        left.contentView.postsBoundsChangedNotifications = true
        right.contentView.postsBoundsChangedNotifications = true

        observations = [
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: left.contentView,
                queue: .main
            ) { [weak self] notification in
                let clipView = notification.object as? NSClipView
                MainActor.assumeIsolated {
                    self?.syncAllVertical(from: clipView)
                }
            },
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: right.contentView,
                queue: .main
            ) { [weak self] notification in
                let clipView = notification.object as? NSClipView
                MainActor.assumeIsolated {
                    self?.syncAllVertical(from: clipView)
                }
            },
        ]
    }

    func detach() {
        removeObservations()
        leftScrollView = nil
        rightScrollView = nil
        leftGutterScrollView = nil
        rightGutterScrollView = nil
    }

    deinit {
        removeObservations()
    }

    private nonisolated func removeObservations() {
        for observation in observations {
            NotificationCenter.default.removeObserver(observation)
        }
        observations.removeAll()
    }

    /// Sets all attached panes to the same vertical clip origin without recursive sync.
    func setVerticalOffset(_ y: CGFloat) {
        applyVerticalOffset(y, excluding: nil)
    }

    /// Aligns every attached scroll view to `source`'s vertical clip origin in one transaction.
    private func syncAllVertical(from source: NSClipView?) {
        guard !isSyncing, let source else { return }
        applyVerticalOffset(source.bounds.origin.y, excluding: source)
    }

    private var allScrollViews: [NSScrollView] {
        [leftScrollView, rightScrollView, leftGutterScrollView, rightGutterScrollView]
            .compactMap { $0 }
    }

    private func applyVerticalOffset(_ y: CGFloat, excluding source: NSClipView?) {
        guard !allScrollViews.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }

        for scrollView in allScrollViews {
            let clipView = scrollView.contentView
            if let source, clipView === source {
                continue
            }
            var origin = clipView.bounds.origin
            guard origin.y != y else { continue }
            origin.y = y
            clipView.setBoundsOrigin(origin)
            scrollView.reflectScrolledClipView(clipView)
        }
    }
}
