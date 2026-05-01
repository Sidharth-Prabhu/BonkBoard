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
        VStack(spacing: 20) {

            // App Icon
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 88)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            // App Name
            Text(appName)
                .font(.system(size: 26, weight: .bold))

            // Version
            Text(versionString)
                .font(.callout)
                .foregroundStyle(.secondary)

            // Description
            Text("BonkBoard detects gentle taps on your Mac and turns them into actions. Configure sensitivity, timing, and gestures to make it yours.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            // Developer Section
            VStack(spacing: 6) {
                Text("Developed by")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Sidharth P L")
                    .font(.headline)

                // 🔗 Portfolio Link (CHANGE THIS URL)
                Link("Contact Developer", destination: URL(string: "https://sidharthprabhu.co.in")!)
                    .font(.callout)
            }
            .padding(.top, 6)

            // Action Links
            HStack(spacing: 20) {
                if let websiteURL = URL(string: "https:bonkboard.sidharthprabhu.co.in") {
                    Link("Visit Website", destination: websiteURL)
                }

//                if let supportURL = URL(string: "mailto:mailtosidharth.me@gmail.com") {
//                    Link("Support", destination: supportURL)
//                }
            }
            .font(.callout)
            .padding(.top, 4)

            Spacer()

            // Footer
            Text("© \(Calendar.current.component(.year, from: Date())) BonkBoard")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 480, height: 360)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    AboutView()
}
