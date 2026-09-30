import SwiftUI

/// Menu commands that target the focused window's `AppViewModel`.
struct HomMergeCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.appViewModel) private var appModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About HomMerge") {
                openWindow(id: "about")
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Tab") {
                appModel?.addTab(select: true)
            }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(appModel == nil)

            Divider()

            Button("Open Left…") {
                appModel?.openLeft()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(appModel == nil)

            Button("Open Right…") {
                appModel?.openRight()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(appModel == nil)

            Button("Compare") {
                appModel?.compareSelected()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!(appModel?.selectedSession?.canCompare ?? false))

            Divider()

            Button("Close Tab") {
                guard let appModel else { return }
                appModel.closeTab(appModel.selectedTabID)
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(appModel == nil)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                appModel?.selectedFileCompare?.undoMerge()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!canMergeUndo)

            Button("Redo") {
                appModel?.selectedFileCompare?.redoMerge()
            }
            .keyboardShortcut("Z", modifiers: .command)
            .disabled(!canMergeRedo)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Left") {
                appModel?.selectedFileCompare?.saveLeft()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!(appModel?.selectedFileCompare?.canSaveLeft ?? false))

            Button("Save Right") {
                appModel?.selectedFileCompare?.saveRight()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!(appModel?.selectedFileCompare?.canSaveRight ?? false))
        }

        CommandMenu("Diff") {
            Button("Refresh") {
                if let fileCompare = appModel?.selectedFileCompare {
                    fileCompare.refresh()
                } else {
                    appModel?.selectedFolderCompare?.refresh()
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!canRefresh)

            Divider()

            Button("First Difference") {
                appModel?.selectedFileCompare?.goFirstDifference()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option, .shift])
            .disabled(!canGoFirst)

            Button("Previous Difference") {
                appModel?.selectedFileCompare?.goPreviousDifference()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            .disabled(!canGoPrevious)

            Button("Current Difference") {
                appModel?.selectedFileCompare?.goCurrentDifference()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!canGoCurrent)

            Button("Nearest Difference at Caret") {
                appModel?.selectedFileCompare?.selectNearestHunkToCaret()
            }
            .keyboardShortcut("/", modifiers: [.command, .option])
            .disabled(!(appModel?.selectedFileCompare?.canSelectNearestHunkToCaret ?? false))

            Button("Next Difference") {
                appModel?.selectedFileCompare?.goNextDifference()
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            .disabled(!canGoNext)

            Button("Last Difference") {
                appModel?.selectedFileCompare?.goLastDifference()
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option, .shift])
            .disabled(!canGoLast)

            Divider()

            Button("Copy Difference to Right") {
                appModel?.selectedFileCompare?.copyHunkToRight()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(!(appModel?.selectedFileCompare?.canCopyHunk ?? false))

            Button("Copy Difference to Left") {
                appModel?.selectedFileCompare?.copyHunkToLeft()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(!(appModel?.selectedFileCompare?.canCopyHunk ?? false))

            Button("Copy Difference to Right and Next") {
                appModel?.selectedFileCompare?.copyHunkToRightAndNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .shift])
            .disabled(!(appModel?.selectedFileCompare?.canCopyHunk ?? false))

            Button("Copy Difference to Left and Next") {
                appModel?.selectedFileCompare?.copyHunkToLeftAndNext()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option, .shift])
            .disabled(!(appModel?.selectedFileCompare?.canCopyHunk ?? false))

            Divider()

            Button("Copy to Right") {
                appModel?.selectedFolderCompare?.copySelectedToRight()
            }
            .disabled(!(appModel?.selectedFolderCompare?.canCopyToRight ?? false))

            Button("Copy to Left") {
                appModel?.selectedFolderCompare?.copySelectedToLeft()
            }
            .disabled(!(appModel?.selectedFolderCompare?.canCopyToLeft ?? false))

            Button("Move to Trash") {
                appModel?.selectedFolderCompare?.deleteSelected()
            }
            .disabled(!(appModel?.selectedFolderCompare?.canDeleteSelected ?? false))

            Divider()

            Button("Compare Selected Folder Files") {
                guard let appModel,
                      let folderCompare = appModel.selectedFolderCompare
                else {
                    return
                }
                folderCompare.openSelectedFileCompares { left, right in
                    appModel.openFileCompareInNewTab(left: left, right: right)
                }
            }
            .disabled(!(appModel?.selectedFolderCompare?.canOpenSelectedFileCompare ?? false))
        }
    }

    private var canGoNext: Bool {
        appModel?.selectedFileCompare?.canGoNextDifference ?? false
    }

    private var canGoPrevious: Bool {
        appModel?.selectedFileCompare?.canGoPreviousDifference ?? false
    }

    private var canGoFirst: Bool {
        guard let navigator = appModel?.selectedFileCompare?.state.navigator else {
            return false
        }
        return navigator.hunkCount > 0
    }

    private var canGoLast: Bool {
        guard let navigator = appModel?.selectedFileCompare?.state.navigator else {
            return false
        }
        return navigator.hunkCount > 0
    }

    private var canGoCurrent: Bool {
        appModel?.selectedFileCompare?.canGoCurrentDifference ?? false
    }

    private var canRefresh: Bool {
        appModel?.selectedFileCompare != nil || appModel?.selectedFolderCompare != nil
    }

    private var canMergeUndo: Bool {
        guard let fileCompare = appModel?.selectedFileCompare else { return false }
        _ = fileCompare.mergeUndoRevision
        return fileCompare.canMergeUndo
    }

    private var canMergeRedo: Bool {
        guard let fileCompare = appModel?.selectedFileCompare else { return false }
        _ = fileCompare.mergeUndoRevision
        return fileCompare.canMergeRedo
    }
}
