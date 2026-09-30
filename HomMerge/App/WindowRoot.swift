import AppKit
import SwiftUI

/// Root view for one window. Owns an independent comparison session.
struct WindowRoot: View {
    @Environment(\.openWindow) private var openWindow
    @State private var appModel: AppViewModel
    @State private var didApplyInitialSession = false

    init() {
        _appModel = State(initialValue: AppViewModel())
    }

    var body: some View {
        ContentView(appModel: appModel)
            .focusedSceneValue(\.appViewModel, appModel)
            .background(
                WindowCloseGuard(
                    shouldClose: { appModel.confirmWindowClose() },
                    onWindowAttached: { window in
                        SessionRegistry.shared.register(appModel, window: window)
                    }
                )
            )
            .onAppear {
                applyInitialSessionIfNeeded()
                openPendingRestoreWindowsIfNeeded()
                if !SessionRegistry.shared.isLaunchResolved {
                    Task { @MainActor in
                        for _ in 0 ..< 20 {
                            if SessionRegistry.shared.isLaunchResolved { break }
                            try? await Task.sleep(for: .milliseconds(50))
                        }
                        applyInitialSessionIfNeeded()
                        openPendingRestoreWindowsIfNeeded()
                    }
                }
            }
            .onDisappear {
                SessionRegistry.shared.unregister(appModel)
            }
    }

    private func applyInitialSessionIfNeeded() {
        guard !didApplyInitialSession else { return }
        guard SessionRegistry.shared.isLaunchResolved else { return }
        didApplyInitialSession = true

        if let request = SessionRegistry.shared.consumeInitialLaunchComparison() {
            appModel.selectedSession?.openComparedFiles(left: request.left, right: request.right)
            return
        }

        if let url = SessionRegistry.shared.consumeInitialSingleFileURL() {
            appModel.selectedSession?.restorePaths(left: url, right: nil)
            return
        }

        if let snapshot = SessionRegistry.shared.consumeInitialRestoreSnapshot() {
            SessionRegistry.shared.unregister(appModel)
            appModel = AppViewModel(restoring: snapshot)
            return
        }

        if let request = SessionRegistry.shared.consumeStagedWarmLaunchComparison() {
            appModel.selectedSession?.openComparedFiles(left: request.left, right: request.right)
            return
        }

        if let url = SessionRegistry.shared.consumeStagedWarmSingleFileURL() {
            appModel.selectedSession?.applyDockDroppedFile(url)
        }
    }

    private func openPendingRestoreWindowsIfNeeded() {
        guard SessionRegistry.shared.isLaunchResolved else { return }
        guard !SessionRegistry.shared.hasRequestedExtraWindows else { return }
        SessionRegistry.shared.markExtraWindowsRequested()
        let pending = SessionRegistry.shared.pendingRestoreWindowCount
        for _ in 0..<pending {
            openWindow(id: "main")
        }
    }
}

/// Installs an `NSWindowDelegate` that asks before closing when the host requests it.
private struct WindowCloseGuard: NSViewRepresentable {
    let shouldClose: () -> Bool
    let onWindowAttached: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldClose: shouldClose, onWindowAttached: onWindowAttached)
    }

    func makeNSView(context: Context) -> WindowAttachView {
        let view = WindowAttachView(frame: .zero)
        view.onWindowAvailable = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowAttachView, context: Context) {
        context.coordinator.shouldClose = shouldClose
        context.coordinator.onWindowAttached = onWindowAttached
        nsView.onWindowAvailable = { window in
            context.coordinator.attach(to: window)
        }
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var shouldClose: () -> Bool
        var onWindowAttached: (NSWindow) -> Void
        private weak var window: NSWindow?
        private weak var previousDelegate: NSWindowDelegate?

        init(shouldClose: @escaping () -> Bool, onWindowAttached: @escaping (NSWindow) -> Void) {
            self.shouldClose = shouldClose
            self.onWindowAttached = onWindowAttached
        }

        @MainActor
        func attach(to window: NSWindow?) {
            guard let window else { return }
            if self.window === window {
                onWindowAttached(window)
                return
            }
            detach()
            previousDelegate = window.delegate
            self.window = window
            window.delegate = self
            onWindowAttached(window)
        }

        @MainActor
        private func detach() {
            if let window, window.delegate === self {
                window.delegate = previousDelegate
            }
            window = nil
            previousDelegate = nil
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if let previousDelegate,
               previousDelegate.responds(to: #selector(NSWindowDelegate.windowShouldClose(_:)))
            {
                let priorAllows = previousDelegate.windowShouldClose?(sender) ?? true
                guard priorAllows else { return false }
            }
            return shouldClose()
        }

        override func responds(to aSelector: Selector!) -> Bool {
            if super.responds(to: aSelector) {
                return true
            }
            return previousDelegate?.responds(to: aSelector) ?? false
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if let previousDelegate, previousDelegate.responds(to: aSelector) {
                return previousDelegate
            }
            return super.forwardingTarget(for: aSelector)
        }
    }
}

private final class WindowAttachView: NSView {
    var onWindowAvailable: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindowAvailable?(window)
        }
    }
}

#Preview {
    WindowRoot()
}
