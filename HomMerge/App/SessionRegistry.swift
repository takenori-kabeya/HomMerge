import AppKit
import Foundation
import os

enum OpenFileHandlingResult: Equatable {
    case accumulating
    case readyToReply
}

@MainActor
final class SessionRegistry {
    static let shared = SessionRegistry()
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("main")

    private final class SessionEntry {
        let appModel: AppViewModel
        weak var window: NSWindow?

        init(appModel: AppViewModel, window: NSWindow?) {
            self.appModel = appModel
            self.window = window
        }
    }

    private var entries: [SessionEntry] = []
    private var restoreQueue: [WindowSnapshot] = []
    private var pendingLaunchComparison: LaunchComparisonRequest?
    private var pendingOpenPaths: [String] = []
    private var pendingOpenURLs: [URL] = []
    private var stagedWarmLaunchComparison: LaunchComparisonRequest?
    private var stagedWarmSingleFileURL: URL?
    private var didResolveLaunch = false
    private var warmLaunchHandlers: [(LaunchComparisonRequest) -> Void] = []
    private var warmOpenFileHandlers: [(URL) -> Void] = []
    private var didRegisterWarmLaunchHandler = false
    private var didRegisterWarmOpenFileHandler = false
    private var didPrepareRestore = false
    private var didRequestExtraWindows = false
    private(set) var shouldPresentMainWindow = false
    private var pendingSingleFileURL: URL?
    private var singleFileDebounceTask: Task<Void, Never>?
    private var emptyOpenDebounceTask: Task<Void, Never>?
    private var awaitingSecondOpenFile = false
    private var awaitingEmptyOpenFiles = false

#if DEBUG
    var singleFileDebounceInterval: Duration = .milliseconds(500)
#else
    private let singleFileDebounceInterval: Duration = .milliseconds(500)
#endif

    private init() {}

    var isLaunchResolved: Bool {
        didResolveLaunch
    }

    /// Accumulates a path from `application(_:open:)` / `application(_:openFiles:)`.
    /// Does not resolve launch; call `resolveLaunch()` from `applicationDidFinishLaunching`.
    func noteOpenPath(_ path: String) -> OpenFileHandlingResult {
        guard !path.isEmpty, !pendingOpenPaths.contains(path) else {
            return .accumulating
        }
        pendingOpenPaths.append(path)
        syncPendingOpenURLsFromPaths()

        return processPendingOpenFiles(preferringStoredURLs: false)
    }

    /// Accepts a batch of paths without treating the first as a single-file open.
    func noteOpenPaths(_ paths: [String]) -> OpenFileHandlingResult {
        let uniquePaths = paths.reduce(into: [String]()) { result, path in
            guard !path.isEmpty, !result.contains(path) else { return }
            result.append(path)
        }
        pendingOpenPaths = uniquePaths
        syncPendingOpenURLsFromPaths()

        return processPendingOpenFiles(preferringStoredURLs: false)
    }

    /// Accepts Launch Services / dock open URLs while preserving security-scoped URL identity.
    func noteOpenURLs(_ urls: [URL]) -> OpenFileHandlingResult {
        let uniqueURLs = urls.reduce(into: [URL]()) { result, url in
            let standardized = url.standardizedFileURL
            let path = standardized.path(percentEncoded: false)
            guard !path.isEmpty, !result.contains(where: { $0.path(percentEncoded: false) == path }) else {
                return
            }
            result.append(standardized)
        }
        pendingOpenURLs = uniqueURLs
        pendingOpenPaths = uniqueURLs.map { $0.path(percentEncoded: false) }

        return processPendingOpenFiles(preferringStoredURLs: true)
    }

    /// Determines cold-launch content once per launch (CLI, drag-and-drop, restore, or empty).
    func resolveLaunch(cliArguments: [String] = CommandLine.arguments) {
        guard !didResolveLaunch else { return }

        if let request = LaunchArgumentsParser.parse(cliArguments) {
            didResolveLaunch = true
            pendingLaunchComparison = request
            restoreQueue = []
            didPrepareRestore = true
            clearPendingOpenFiles()
            if !LaunchArgumentsParser.isFlagBasedComparison(cliArguments) {
                requestMainWindowPresentation()
            }
            return
        }

        if let request = comparisonRequestFromPendingOpens(preferringStoredURLs: true) {
            didResolveLaunch = true
            pendingLaunchComparison = request
            restoreQueue = []
            didPrepareRestore = true
            clearPendingOpenFiles()
            requestMainWindowPresentation()
            return
        }

        if pendingOpenPaths.count == 1 {
            scheduleSingleFileDebounce()
            return
        }

        scheduleEmptyOpenDebounce()
    }

    func registerWarmLaunchHandlerIfNeeded(_ handler: @escaping (LaunchComparisonRequest) -> Void) {
        guard !didRegisterWarmLaunchHandler else { return }
        didRegisterWarmLaunchHandler = true
        warmLaunchHandlers.append(handler)
    }

    func registerWarmOpenFileHandlerIfNeeded(_ handler: @escaping (URL) -> Void) {
        guard !didRegisterWarmOpenFileHandler else { return }
        didRegisterWarmOpenFileHandler = true
        warmOpenFileHandlers.append(handler)
    }

    func consumeInitialLaunchComparison() -> LaunchComparisonRequest? {
        guard let request = pendingLaunchComparison else {
            return nil
        }
        pendingLaunchComparison = nil
        return request
    }

    func consumeInitialRestoreSnapshot() -> WindowSnapshot? {
        guard !restoreQueue.isEmpty else { return nil }
        return restoreQueue.removeFirst()
    }

    func consumeStagedWarmLaunchComparison() -> LaunchComparisonRequest? {
        guard let request = stagedWarmLaunchComparison else { return nil }
        stagedWarmLaunchComparison = nil
        return request
    }

    func consumeStagedWarmSingleFileURL() -> URL? {
        guard let url = stagedWarmSingleFileURL else { return nil }
        stagedWarmSingleFileURL = nil
        return url
    }

    func consumeInitialSingleFileURL() -> URL? {
        guard let url = pendingSingleFileURL else { return nil }
        pendingSingleFileURL = nil
        return url
    }

    func consumeShouldPresentMainWindow() -> Bool {
        defer { shouldPresentMainWindow = false }
        return shouldPresentMainWindow
    }

    @discardableResult
    func deliverWarmLaunchComparison(_ request: LaunchComparisonRequest) -> Bool {
        let entry = entries.first(where: { $0.window?.isKeyWindow == true }) ?? entries.last
        guard let entry else { return false }
        entry.appModel.selectedSession?.openComparedFiles(left: request.left, right: request.right)
        entry.window?.makeKeyAndOrderFront(nil)
        return true
    }

    @discardableResult
    func deliverWarmOpenFile(_ url: URL) -> Bool {
        let entry = entries.first(where: { $0.window?.isKeyWindow == true }) ?? entries.last
        guard let entry else { return false }
        entry.appModel.selectedSession?.applyDockDroppedFile(url)
        entry.window?.makeKeyAndOrderFront(nil)
        return true
    }

    /// Loads persisted snapshots once for this launch and fills the restore queue.
    /// Queue order is back→front so later `openWindow` calls end up frontmost.
    func prepareRestoreIfNeeded() {
        guard !didPrepareRestore else { return }
        didPrepareRestore = true
#if DEBUG
        let snapshot = persistenceLoaderForTesting?() ?? SessionPersistence.load()
#else
        let snapshot = SessionPersistence.load()
#endif
        if let snapshot, !snapshot.windows.isEmpty {
            restoreQueue = SessionWindowOrdering.restoreOpenOrderFrontToBack(snapshot.windows)
        } else {
            restoreQueue = []
        }
    }

    func consumeRestoreQueue() -> WindowSnapshot? {
        consumeInitialRestoreSnapshot()
    }

    var pendingRestoreWindowCount: Int {
        restoreQueue.count
    }

    func markExtraWindowsRequested() {
        didRequestExtraWindows = true
    }

    var hasRequestedExtraWindows: Bool {
        didRequestExtraWindows
    }

    func register(_ appModel: AppViewModel, window: NSWindow) {
        window.identifier = Self.mainWindowIdentifier

        // Restore can replace AppViewModel while the NSWindow stays the same; drop the stale entry.
        entries.removeAll { $0.window === window && $0.appModel !== appModel }

        if let index = entries.firstIndex(where: { $0.appModel === appModel }) {
            entries[index].window = window
        } else {
            entries.append(SessionEntry(appModel: appModel, window: window))
        }
    }

    func unregister(_ appModel: AppViewModel) {
        entries.removeAll { $0.appModel === appModel }
    }

    var unsavedFileChangeTabCount: Int {
        entries.reduce(into: 0) { total, entry in
            total += entry.appModel.unsavedFileChangeTabCount
        }
    }

    var windowsWithUnsavedFileChanges: Int {
        entries.reduce(into: 0) { total, entry in
            if entry.appModel.unsavedFileChangeTabCount > 0 {
                total += 1
            }
        }
    }

    /// Returns `.terminateCancel` when the user cancels discarding unsaved file-compare changes.
    func confirmApplicationTerminate() -> NSApplication.TerminateReply {
        let dirtyTabCount = unsavedFileChangeTabCount
        guard dirtyTabCount > 0 else {
            return .terminateNow
        }

        let dirtyWindowCount = windowsWithUnsavedFileChanges
        let alert = NSAlert()
        alert.messageText = String(localized: "Discard unsaved changes?")
        switch (dirtyTabCount, dirtyWindowCount) {
        case (1, 1):
            alert.informativeText = String(
                localized: "You have a tab with unsaved file compare changes."
            )
        case (_, 1):
            alert.informativeText = String(
                localized: "You have \(dirtyTabCount) tabs with unsaved file compare changes."
            )
        default:
            alert.informativeText = String(
                localized: "You have \(dirtyTabCount) tabs with unsaved file compare changes across \(dirtyWindowCount) windows."
            )
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Discard"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func captureAndSave() {
        let snapshotEntries: [(windowNumber: Int, snapshot: WindowSnapshot)] = entries.compactMap { entry in
            guard let window = entry.window else { return nil }
            return (window.windowNumber, entry.appModel.makeSnapshot())
        }

        let orderedNumbers = NSApp.orderedWindows
            .filter { window in
                window.identifier == Self.mainWindowIdentifier
                    || entries.contains(where: { $0.window === window })
            }
            .map(\.windowNumber)

        let windows = SessionWindowOrdering.snapshotsFrontToBack(
            entries: snapshotEntries,
            orderedWindowNumbersFrontToBack: orderedNumbers
        )

        if windows.isEmpty {
            SessionPersistence.clear()
        } else {
            SessionPersistence.save(AppSessionSnapshot(windows: windows))
        }
    }

    private func processPendingOpenFiles(preferringStoredURLs: Bool) -> OpenFileHandlingResult {
        guard let request = comparisonRequestFromPendingOpens(preferringStoredURLs: preferringStoredURLs) else {
            if didResolveLaunch, pendingOpenPaths.count == 1 {
                let url = pendingOpenURLs.first
                    ?? URL(
                        fileURLWithPath: (pendingOpenPaths[0] as NSString).expandingTildeInPath,
                        isDirectory: false
                    ).standardizedFileURL
                clearPendingOpenFiles()
                handleWarmSingleOpenURL(url)
                return .readyToReply
            }
            if awaitingEmptyOpenFiles, pendingOpenPaths.count == 1 {
                scheduleSingleFileDebounce()
            }
            return .accumulating
        }

        if awaitingSecondOpenFile || awaitingEmptyOpenFiles {
            finalizeOpenFileComparison(request)
            return .readyToReply
        }

        if didResolveLaunch {
            clearPendingOpenFiles()
            handleWarmLaunchComparison(request)
        }

        return .readyToReply
    }

    private func comparisonRequestFromPendingOpens(preferringStoredURLs: Bool) -> LaunchComparisonRequest? {
        if preferringStoredURLs, pendingOpenURLs.count >= 2 {
            return LaunchComparisonRequest(
                left: pendingOpenURLs[0],
                right: pendingOpenURLs[1]
            )
        }
        return LaunchArgumentsParser.parseOpenFiles(pendingOpenPaths)
    }

    private func syncPendingOpenURLsFromPaths() {
        pendingOpenURLs = pendingOpenPaths.map { path in
            URL(
                fileURLWithPath: (path as NSString).expandingTildeInPath,
                isDirectory: false
            ).standardizedFileURL
        }
    }

    private func clearPendingOpenFiles() {
        pendingOpenPaths.removeAll()
        pendingOpenURLs.removeAll()
    }

    private func handleWarmLaunchComparison(_ request: LaunchComparisonRequest) {
#if DEBUG
        lastWarmLaunchComparisonForTesting = request
#endif
        restoreQueue = []
        if deliverWarmLaunchComparison(request) {
            return
        }
        stagedWarmLaunchComparison = request
        let handlers = warmLaunchHandlers
        for handler in handlers {
            handler(request)
        }
    }

    private func handleWarmSingleOpenURL(_ url: URL) {
        if deliverWarmOpenFile(url) {
            return
        }
        stagedWarmSingleFileURL = url
        let handlers = warmOpenFileHandlers
        for handler in handlers {
            handler(url)
        }
    }

    private func requestMainWindowPresentation() {
        shouldPresentMainWindow = true
        AppState.shared.presentMainWindowToken += 1
    }

    private func scheduleEmptyOpenDebounce() {
        cancelEmptyOpenDebounce()
        cancelSingleFileDebounce()
        awaitingEmptyOpenFiles = true
        awaitingSecondOpenFile = false
        let interval = singleFileDebounceInterval
        emptyOpenDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            finalizeEmptyOpenAwait()
        }
    }

    private func cancelEmptyOpenDebounce() {
        emptyOpenDebounceTask?.cancel()
        emptyOpenDebounceTask = nil
    }

    private func scheduleSingleFileDebounce() {
        cancelEmptyOpenDebounce()
        awaitingEmptyOpenFiles = false
        cancelSingleFileDebounce()
        awaitingSecondOpenFile = true
        let interval = singleFileDebounceInterval
        singleFileDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            finalizeSingleFileOpen()
        }
    }

    private func cancelSingleFileDebounce() {
        singleFileDebounceTask?.cancel()
        singleFileDebounceTask = nil
    }

    private func finalizeOpenFileComparison(_ request: LaunchComparisonRequest) {
        cancelSingleFileDebounce()
        cancelEmptyOpenDebounce()
        awaitingSecondOpenFile = false
        awaitingEmptyOpenFiles = false
        pendingLaunchComparison = request
        restoreQueue = []
        didPrepareRestore = true
        didResolveLaunch = true
        clearPendingOpenFiles()
        requestMainWindowPresentation()
    }

    private func finalizeEmptyOpenAwait() {
        guard awaitingEmptyOpenFiles, pendingOpenPaths.isEmpty else { return }
        cancelEmptyOpenDebounce()
        awaitingEmptyOpenFiles = false
        didResolveLaunch = true
        prepareRestoreIfNeeded()
        clearPendingOpenFiles()
    }

    private func finalizeSingleFileOpen() {
        guard awaitingSecondOpenFile, pendingOpenPaths.count == 1 else { return }
        cancelSingleFileDebounce()
        awaitingSecondOpenFile = false

        let url = pendingOpenURLs.first ?? {
            let path = (pendingOpenPaths[0] as NSString).expandingTildeInPath
            guard !path.isEmpty else { return nil as URL? }
            return URL(fileURLWithPath: path, isDirectory: false).standardizedFileURL
        }()

        guard let url else {
            didResolveLaunch = true
            didPrepareRestore = true
            restoreQueue = []
            clearPendingOpenFiles()
            return
        }

        pendingSingleFileURL = url
        didResolveLaunch = true
        didPrepareRestore = true
        restoreQueue = []
        clearPendingOpenFiles()
        requestMainWindowPresentation()
        NSApplication.shared.reply(toOpenOrPrint: .success)
    }

#if DEBUG
    var persistenceLoaderForTesting: (() -> AppSessionSnapshot?)?

    func resetLaunchStateForTesting() {
        cancelSingleFileDebounce()
        cancelEmptyOpenDebounce()
        awaitingSecondOpenFile = false
        awaitingEmptyOpenFiles = false
        pendingSingleFileURL = nil
        clearPendingOpenFiles()
        didResolveLaunch = false
        warmLaunchHandlers = []
        warmOpenFileHandlers = []
        stagedWarmLaunchComparison = nil
        stagedWarmSingleFileURL = nil
        pendingLaunchComparison = nil
        restoreQueue = []
        didPrepareRestore = false
        didRequestExtraWindows = false
        didRegisterWarmLaunchHandler = false
        didRegisterWarmOpenFileHandler = false
        shouldPresentMainWindow = false
        singleFileDebounceInterval = .milliseconds(500)
        persistenceLoaderForTesting = nil
        lastWarmLaunchComparisonForTesting = nil
    }

    private(set) var lastWarmLaunchComparisonForTesting: LaunchComparisonRequest?

    func awaitSingleFileDebounceForTesting() async {
        await singleFileDebounceTask?.value
    }

    /// Cancels the debounce task and runs the same completion path the timer would invoke.
    func completeSingleFileDebounceForTesting() {
        cancelSingleFileDebounce()
        finalizeSingleFileOpen()
    }

    func completeEmptyOpenDebounceForTesting() {
        cancelEmptyOpenDebounce()
        finalizeEmptyOpenAwait()
    }

    var isAwaitingSecondOpenFileForTesting: Bool {
        awaitingSecondOpenFile
    }

    var isAwaitingEmptyOpenFilesForTesting: Bool {
        awaitingEmptyOpenFiles
    }

    var hasPendingLaunchComparisonForTesting: Bool {
        pendingLaunchComparison != nil
    }

    var restoreQueueCountForTesting: Int {
        restoreQueue.count
    }

    var isLaunchResolvedForTesting: Bool {
        didResolveLaunch
    }

    var shouldPresentMainWindowForTesting: Bool {
        shouldPresentMainWindow
    }
#endif
}

@MainActor
final class HomMergeAppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        SessionRegistry.shared.resolveLaunch()
    }

    @objc func compareWithHomMerge(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = FinderCompareService.fileURLs(from: pboard)
        guard FinderCompareService.comparisonRequest(fromFileURLs: urls) != nil else {
            return
        }
        _ = SessionRegistry.shared.noteOpenURLs(urls)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SessionRegistry.shared.confirmApplicationTerminate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionRegistry.shared.captureAndSave()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if SessionRegistry.shared.noteOpenURLs(urls) == .readyToReply {
            application.reply(toOpenOrPrint: .success)
        }
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        if SessionRegistry.shared.noteOpenPaths(filenames) == .readyToReply {
            application.reply(toOpenOrPrint: .success)
        }
    }
}
