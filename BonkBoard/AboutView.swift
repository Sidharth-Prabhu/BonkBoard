import SwiftUI
import AppKit

struct AboutView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? "BonkBoard"
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 6)

            Text(appName)
                .font(.system(size: 24, weight: .bold))

            Text(versionString)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("BonkBoard detects gentle taps on your Mac and turns them into actions. Configure sensitivity, timing, and gestures to make it yours.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 16) {
                if let websiteURL = URL(string: "https://example.com/bonkboard") {
                    Link("Website", destination: websiteURL)
                }
                if let supportURL = URL(string: "mailto:support@example.com") {
                    Link("Support", destination: supportURL)
                }
            }
            .font(.callout)

            Spacer(minLength: 0)

            Text("© \(Calendar.current.component(.year, from: Date())) BonkBoard. All rights reserved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 360)
    }
}

#Preview {
    AboutView()
}
