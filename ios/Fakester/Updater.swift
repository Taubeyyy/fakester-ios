import SwiftUI
import UIKit

// New version? On launch, asks for the latest GitHub release (build-<N>) and offers to
// install it via TrollStore. Only for the TrollStore build - the App Store forbids this,
// so it must be removed for an App Store build (Apple then handles updates itself).

@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    struct UpdateInfo: Equatable {
        let build: Int
        let url: String
        let text: String
    }

    @Published private(set) var latest: UpdateInfo?
    private var previous: Date?

    var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    func checkForUpdate() async {
        // at most every 10 minutes (GitHub allows 60 unauthenticated requests per hour)
        if let previous, Date().timeIntervalSince(previous) < 600 { return }
        previous = Date()

        struct ReleaseAsset: Decodable { let name: String; let browser_download_url: String }
        struct GitHubRelease: Decodable { let tag_name: String; let body: String?; let assets: [ReleaseAsset] }

        var request = URLRequest(url: URL(string: "https://api.github.com/repos/Taubeyyy/fakester-ios/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        guard let (bytes, _) = try? await URLSession.shared.data(for: request),
              let v = try? JSONDecoder().decode(GitHubRelease.self, from: bytes),
              let build = Int(v.tag_name.replacingOccurrences(of: "build-", with: "")),
              build > currentBuild,
              let ipa = v.assets.first(where: { $0.name.hasSuffix(".ipa") }) else { return }
        // Release text is "Commit abc1234: <message>" - show only the message
        var text = v.body ?? ""
        if let colon = text.range(of: ": "), text.hasPrefix("Commit ") { text = String(text[colon.upperBound...]) }
        withAnimation(.easeOut(duration: 0.25)) {
            latest = UpdateInfo(build: build, url: ipa.browser_download_url, text: text)
        }
    }

    func install() {
        guard let latest else { return }
        let encoded = latest.url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? latest.url
        if let installURL = URL(string: "apple-magnifier://install?url=\(encoded)") {
            UIApplication.shared.open(installURL)
        }
    }
}

/// Card on the home screen when a new version is available.
struct UpdateCard: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        if let latest = updater.latest {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NEW VERSION").eyebrow()
                    Text("Build \(latest.build) is out")
                        .font(.brand(18, .heavy))
                        .foregroundColor(Palette.foreground)
                    if !latest.text.isEmpty {
                        Text(latest.text)
                            .font(.brand(13))
                            .foregroundColor(Palette.subdued)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Install") {
                        Haptics.tap()
                        updater.install()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
