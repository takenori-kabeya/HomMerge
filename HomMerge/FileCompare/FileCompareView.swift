import DiffEngine
import SwiftUI

/// Result UI for a file-to-file compare (paths are owned by `CompareSessionViewModel`).
struct FileCompareView: View {
    @Bindable var viewModel: FileCompareViewModel
    @AppStorage(FileCompareToolbarPreferences.usesIconsKey) private var useIconToolbar = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            if viewModel.showsFormatStatusBar {
                Divider()
                formatStatusBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            FileCompareToolbarButton(
                item: .nearestDiff,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canSelectNearestHunkToCaret,
                action: viewModel.selectNearestHunkToCaret
            )
            
            Divider().frame(height: 16)
            
            FileCompareToolbarButton(
                item: .nextDiff,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canGoNextDifference,
                action: viewModel.goNextDifference
            )
            FileCompareToolbarButton(
                item: .previousDiff,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canGoPreviousDifference,
                action: viewModel.goPreviousDifference
            )
            
            Divider().frame(height: 16)
            
            FileCompareToolbarButton(
                item: .firstDiff,
                useIcons: useIconToolbar,
                isEnabled: viewModel.state.navigator.hunkCount > 0,
                action: viewModel.goFirstDifference
            )
            FileCompareToolbarButton(
                item: .currentDiff,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canGoCurrentDifference,
                action: viewModel.goCurrentDifference
            )
            FileCompareToolbarButton(
                item: .lastDiff,
                useIcons: useIconToolbar,
                isEnabled: viewModel.state.navigator.hunkCount > 0,
                action: viewModel.goLastDifference
            )

            Divider().frame(height: 16)
            
            FileCompareToolbarButton(
                item: .copyRight,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canCopyHunk,
                action: viewModel.copyHunkToRight
            )
            FileCompareToolbarButton(
                item: .copyLeft,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canCopyHunk,
                action: viewModel.copyHunkToLeft
            )

            Divider().frame(height: 16)
            
            FileCompareToolbarButton(
                item: .copyRightAndNext,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canCopyHunk,
                action: viewModel.copyHunkToRightAndNext
            )
            FileCompareToolbarButton(
                item: .copyLeftAndNext,
                useIcons: useIconToolbar,
                isEnabled: viewModel.canCopyHunk,
                action: viewModel.copyHunkToLeftAndNext
            )

            Divider().frame(height: 16)
            
            FileCompareToolbarButton(
                item: .refresh,
                useIcons: useIconToolbar,
                action: viewModel.refresh
            )

            Spacer()

            Toggle("Ignore Whitespace", isOn: $viewModel.ignoreWhitespace)
                .toggleStyle(.checkbox)
            Toggle("Ignore Blank Lines", isOn: $viewModel.ignoreBlankLines)
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var formatStatusBar: some View {
        HStack(spacing: 0) {
            formatStatusCell(text: viewModel.leftFormatStatusText)
            Divider()
            formatStatusCell(text: viewModel.rightFormatStatusText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func formatStatusCell(text: String?) -> some View {
        Text(text ?? "—")
            .font(.caption)
            .foregroundStyle(text == nil ? .tertiary : .secondary)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.canCompare {
            DiffPanePair(
                lines: viewModel.state.presentation,
                hunks: viewModel.locationHunks,
                currentHunkIndex: viewModel.currentHunkIndex,
                highlightedRowRange: viewModel.highlightedRowRange,
                scrollToRow: viewModel.scrollToRow,
                scrollToken: viewModel.scrollToken,
                scrollViewportAnchorFraction: viewModel.scrollViewportAnchorFraction,
                paneApplyToken: viewModel.paneApplyToken,
                nearestHunkSelectToken: viewModel.nearestHunkSelectToken,
                pendingCaretRemap: viewModel.pendingCaretRemap,
                caretLineStartRestoreToken: viewModel.caretLineStartRestoreToken,
                pendingCaretLineStartRestore: viewModel.pendingCaretLineStartRestore,
                mergeUndoManager: viewModel.undoManager,
                onSelectHunk: { index in
                    viewModel.selectHunkAndScroll(index)
                },
                onCommitEdit: { side, paneText in
                    viewModel.commitPaneEdit(side: side, paneText: paneText)
                },
                onEditingChange: { sides in
                    viewModel.setUncommittedEditSides(sides)
                },
                onPaneFocusChange: { focused in
                    viewModel.setPaneFocused(focused)
                },
                onCaretContextChange: { row, side, fraction in
                    viewModel.setCaretContext(row: row, side: side, viewportAnchorFraction: fraction)
                },
                onConsumeCaretRemap: {
                    viewModel.clearPendingCaretRemap()
                },
                onConsumeCaretLineStartRestore: {
                    viewModel.clearPendingCaretLineStartRestore()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        } else {
            Text(viewModel.statusText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
    }
}
