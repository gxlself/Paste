//
//  UpdateChecker.swift
//  Paste
//
//  Checks GitHub Releases for a newer build, downloads its installer package and hands it to
//  Installer.app. The app is sandboxed, so it cannot replace itself; Installer does the install.
//

import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {

    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading(progress: Double)
        case installerOpened
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/gxlself/Paste/releases/latest")!

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private var latest: (version: String, packageURL: URL?)?
    private var progressObservation: NSKeyValueObservation?

    /// The Mac App Store forbids apps from updating themselves, so the feature is off for
    /// App Store builds (recognised by their receipt) and only serves the GitHub download.
    static var isSupported: Bool {
        guard let receipt = Bundle.main.appStoreReceiptURL else { return true }
        return !FileManager.default.fileExists(atPath: receipt.path)
    }

    static var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    /// True when `remote` (e.g. "v1.11.0") is a higher dotted version than `local`.
    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ version: String) -> [Int] {
            let trimmed = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            return trimmed.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let (a, b) = (parts(remote), parts(local))
        for i in 0..<max(a.count, b.count) {
            let (x, y) = (i < a.count ? a[i] : 0, i < b.count ? b[i] : 0)
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Check

    func check() {
        guard Self.isSupported else { return }
        switch state {
        case .checking, .downloading: return
        default: break
        }
        state = .checking
        Task { await performCheck() }
    }

    private func performCheck() async {
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw UpdateError.badResponse
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            guard Self.isNewer(version, than: Self.currentVersion) else {
                latest = nil
                state = .upToDate
                return
            }
            let package = release.assets.first { $0.name.hasSuffix(".pkg") }?.browserDownloadURL
            latest = (version, package)
            state = .available(version: version)
        } catch {
            AppLog.warning("Update check failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Download and install

    func downloadAndInstall() {
        guard case .available = state, let latest else { return }
        guard let url = latest.packageURL, Self.isTrusted(url) else {
            state = .failed(UpdateError.noPackage.localizedDescription)
            return
        }
        state = .downloading(progress: 0)
        Task { await performDownload(url) }
    }

    private func performDownload(_ url: URL) async {
        do {
            let file = try await download(url)
            progressObservation = nil
            guard NSWorkspace.shared.open(file) else { throw UpdateError.cannotOpenInstaller }
            state = .installerOpened
        } catch {
            progressObservation = nil
            AppLog.warning("Update download failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    private func download(_ url: URL) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PasteUpdate", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(url.lastPathComponent)

        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { temporary, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let temporary, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    continuation.resume(throwing: UpdateError.badResponse)
                    return
                }
                do {
                    // The temporary file is deleted when this handler returns, so move it now.
                    try FileManager.default.moveItem(at: temporary, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(progress: fraction)
                }
            }
            task.resume()
        }
    }

    /// Only follow download links that GitHub itself serves over https.
    private static func isTrusted(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host else { return false }
        return host == "github.com" || host.hasSuffix(".githubusercontent.com")
    }

    private enum UpdateError: LocalizedError {
        case badResponse
        case noPackage
        case cannotOpenInstaller

        var errorDescription: String? {
            switch self {
            case .badResponse:
                return String(localized: "update.error.badResponse", defaultValue: "Could not reach the update server.")
            case .noPackage:
                return String(localized: "update.error.noPackage", defaultValue: "This release has no installer package.")
            case .cannotOpenInstaller:
                return String(localized: "update.error.cannotOpenInstaller", defaultValue: "Could not open the installer.")
            }
        }
    }
}
