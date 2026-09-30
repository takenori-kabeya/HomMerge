import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Incremented when a file-open cold launch needs `openWindow(id: "main")`.
    @Published var presentMainWindowToken = 0
}

@main
struct HomMergeApp: App {
    @NSApplicationDelegateAdaptor(HomMergeAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            WindowRoot()
                .onAppear {
                    SessionRegistry.shared.registerWarmLaunchHandlerIfNeeded { request in
                        if !SessionRegistry.shared.deliverWarmLaunchComparison(request) {
                            openWindow(id: "main")
                        }
                    }
                    SessionRegistry.shared.registerWarmOpenFileHandlerIfNeeded { url in
                        if !SessionRegistry.shared.deliverWarmOpenFile(url) {
                            openWindow(id: "main")
                        }
                    }
                }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            HomMergeCommands()
        }
        .environmentObject(appState)
        .onChange(of: appState.presentMainWindowToken) { _, token in
            guard token > 0 else { return }
            openWindow(id: "main")
        }

        Window("About HomMerge", id: "about") {
            AboutView()
        }
        .defaultSize(width: 560, height: 520)

        Settings {
            SettingsView()
        }
    }
}
