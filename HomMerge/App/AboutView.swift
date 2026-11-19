import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let icon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("HomMerge")
                        .font(.title2.weight(.semibold))
                    Text("Version \(Bundle.main.shortVersionString) (\(Bundle.main.buildVersionString))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Copyright © 2026 Takenori Kabeya and HomMerge contributors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("End User License Agreement (EULA)")
                .font(.headline)

            BundledRTFView(
                resourceName: "EULA",
                missingMessage: String(localized: "Could not load EULA.rtf.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    var buildVersionString: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

#Preview {
    AboutView()
}
