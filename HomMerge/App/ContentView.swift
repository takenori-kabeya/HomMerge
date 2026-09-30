import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            CompareTabBar(appModel: appModel)
            Divider()

            ZStack {
                ForEach(appModel.tabs) { tab in
                    CompareSessionView(session: tab.session) { left, right in
                        appModel.openFileCompareInNewTab(left: left, right: right)
                    }
                    .opacity(tab.id == appModel.selectedTabID ? 1 : 0)
                    .allowsHitTesting(tab.id == appModel.selectedTabID)
                    .accessibilityHidden(tab.id != appModel.selectedTabID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView(appModel: AppViewModel())
}
