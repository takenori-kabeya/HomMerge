import SwiftUI

struct HelpView: View {
    var body: some View {
        BundledRTFView(
            resourceName: HelpDocumentResource.rtfResourceName(),
            fileExtension: HelpDocumentResource.fileExtension,
            missingMessage: String(localized: "Could not load Help.rtf.")
        )
        .padding(20)
        .frame(minWidth: 560, minHeight: 480)
    }
}

#Preview {
    HelpView()
}
