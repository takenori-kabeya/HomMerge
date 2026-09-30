import SwiftUI

struct SettingsView: View {
    @AppStorage(EditorPreferences.tabInsertsSpacesKey) private var tabInsertsSpaces = false
    @AppStorage(EditorPreferences.tabWidthKey) private var tabWidth = EditorPreferences.defaultTabWidth

    private var tabWidthSelection: Binding<Int> {
        Binding(
            get: { EditorPreferences.clampedTabWidth(tabWidth) },
            set: { tabWidth = EditorPreferences.clampedTabWidth($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Tab Key", selection: $tabInsertsSpaces) {
                    Text("Inserts Tab Character").tag(false)
                    Text("Inserts Spaces").tag(true)
                }

                Picker("Tab Width", selection: tabWidthSelection) {
                    ForEach(EditorPreferences.allowedTabWidths, id: \.self) { width in
                        Text("\(width) spaces").tag(width)
                    }
                }
            } header: {
                Text("Editor")
            } footer: {
                Text("Used for tab character display and for space insertion stops.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 180)
    }
}

#Preview {
    SettingsView()
}
