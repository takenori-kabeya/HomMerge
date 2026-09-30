import SwiftUI

struct CompareTabBar: View {
    @Bindable var appModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appModel.tabs) { tab in
                        tabButton(for: tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            Button {
                appModel.addTab(select: true)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .help("New Tab")
            .padding(.trailing, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func tabButton(for tab: CompareTab) -> some View {
        let isSelected = tab.id == appModel.selectedTabID

        return HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                Text(tab.title)
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appModel.selectTab(tab.id)
            }

            Button {
                appModel.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Close Tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isSelected ? Color(nsColor: .separatorColor) : Color.clear,
                    lineWidth: 1
                )
        )
        .contextMenu {
            Button("Close Tab") {
                appModel.closeTab(tab.id)
            }
            Button("New Tab") {
                appModel.addTab(select: true)
            }
        }
    }

    private func iconName(for tab: CompareTab) -> String {
        switch tab.session.phase {
        case .idle:
            return "plus.square.on.square"
        case .files:
            return "doc.text"
        case .folders:
            return "folder"
        }
    }
}
