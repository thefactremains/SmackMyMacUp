import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case error(String)
    }

    @Published var state: State = .idle

    private let repo = "thefactremains/SmackMyMacUp"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func check() {
        state = .checking
        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            state = .error("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    state = .error("GitHub API error")
                    return
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlUrl = json["html_url"] as? String,
                      let releaseUrl = URL(string: htmlUrl) else {
                    state = .error("Unexpected response")
                    return
                }

                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                if isNewer(remote: remote, local: currentVersion) {
                    state = .available(version: remote, url: releaseUrl)
                } else {
                    state = .upToDate
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
