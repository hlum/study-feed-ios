import SafariServices
import SwiftUI

/// Opens an article inside the app. Card content comes from the server and, through it,
/// from the web, so only plain http(s) links are ever opened.
struct SourceLink: View {
    let source: Source?
    @State private var target: LinkTarget?

    private struct LinkTarget: Identifiable {
        let url: URL
        let host: String
        var id: URL { url }
    }

    var body: some View {
        if let raw = source?.url, let url = URL(string: raw),
           ["http", "https"].contains(url.scheme?.lowercased()), let host = url.host() {
            Button { target = LinkTarget(url: url, host: host) } label: {
                Label("Read on \(host)", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .sheet(item: $target) { SafariView(url: $0.url).ignoresSafeArea() }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
