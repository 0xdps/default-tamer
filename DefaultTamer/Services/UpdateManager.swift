import Foundation

@MainActor
class UpdateManager: ObservableObject {
    @Published var hasUpdate = false
    @Published var latestRelease: AvailableUpdate?
    @Published var isChecking = false
    @Published var errorMessage: String?
    @Published var lastCheckTime: Date?
    
    private let apiURL = "https://api.github.com/repos/0xdps/default-tamer/releases/latest"
    private let timeoutInterval: TimeInterval = 10
    private let minimumCheckInterval: TimeInterval = TimeConstants.updateCheckMinimumInterval // 1 hour
    private let rateLimitKey = "defaultTamer.lastUpdateCheck"
    
    init() {
        // Load last check time from UserDefaults
        if let lastCheck = UserDefaults.standard.object(forKey: rateLimitKey) as? Date {
            lastCheckTime = lastCheck
        }
    }
    
    /// Check for available updates with rate limiting
    /// - Parameter forced: Set to true to bypass rate limiting (e.g., manual check button)
    func checkForUpdates(forced: Bool = false) async {
        // Check rate limit unless forced
        if !forced {
            if let lastCheck = lastCheckTime ?? UserDefaults.standard.object(forKey: rateLimitKey) as? Date {
                let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
                if timeSinceLastCheck < minimumCheckInterval {
                    let remainingMinutes = Int((minimumCheckInterval - timeSinceLastCheck) / 60)
                    DispatchQueue.main.async {
                        self.errorMessage = "Please wait \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") before checking again"
                        self.isChecking = false
                    }
                    return
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isChecking = true
            self.errorMessage = nil
        }
        
        do {
            let release = try await fetchLatestRelease()
            
            // Update last check time on successful check
            let now = Date()
            DispatchQueue.main.async {
                self.lastCheckTime = now
                UserDefaults.standard.set(now, forKey: self.rateLimitKey)
                
                if self.isNewerVersion(release.version) {
                    self.latestRelease = AvailableUpdate(
                        version: release.version,
                        name: release.name,
                        dmgAsset: release.assets.first(where: { $0.isDMG }),
                        publishedAt: release.publishedAt
                    )
                    self.hasUpdate = true
                } else {
                    self.hasUpdate = false
                    self.errorMessage = nil // Clear any previous errors
                }
                self.isChecking = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isChecking = false
                self.handleError(error)
            }
        }
    }
    
    /// Fetch latest release from GitHub API
    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: apiURL) else {
            throw UpdateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("DefaultTamer/0.0.1", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for 404 (no releases published yet)
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 {
                throw UpdateError.noReleasesPublished
            }
            if httpResponse.statusCode != 200 {
                throw UpdateError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: data)
        
        return release
    }
    
    /// Compare versions: returns true if latest > current
    private func isNewerVersion(_ latestVersion: String) -> Bool {
        let currentVersion = AppVersion.current
        return latestVersion.versionCompare(currentVersion) == .orderedDescending
    }
    
    /// Handle errors gracefully during development
    private func handleError(_ error: Error) {
        if let updateError = error as? UpdateError {
            switch updateError {
            case .noReleasesPublished:
                // Development mode - no releases yet, silently skip
                self.errorMessage = nil
                self.hasUpdate = false
            case .networkError(let message):
                // Network issue - show message but don't crash
                self.errorMessage = "Network error: \(message). Check your connection."
                self.hasUpdate = false
            case .invalidURL:
                self.errorMessage = "Invalid update URL."
                self.hasUpdate = false
            case .apiError(let message):
                self.errorMessage = "Update check failed: \(message). Try again later."
                self.hasUpdate = false
            case .decodingError:
                // API response format changed - silent skip
                self.errorMessage = nil
                self.hasUpdate = false
            }
        } else if let networkError = error as? URLError {
            self.errorMessage = "Network error: \(networkError.localizedDescription)"
            self.hasUpdate = false
        } else {
            self.errorMessage = "Update check failed. Try again later."
            self.hasUpdate = false
        }
        
        debugLog("[UpdateManager] Error: \(error)")
    }
}

// MARK: - Version Comparison
extension String {
    /// Compare semantic versions: "0.0.2" vs "0.0.1"
    func versionCompare(_ other: String) -> ComparisonResult {
        let v1 = self.split(separator: ".").compactMap { Int($0) }
        let v2 = other.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1.count, v2.count)
        
        for i in 0..<maxLength {
            let first = i < v1.count ? v1[i] : 0
            let second = i < v2.count ? v2[i] : 0
            
            if first > second { return .orderedDescending }
            if first < second { return .orderedAscending }
        }
        
        return .orderedSame
    }
}

// MARK: - Models
struct AvailableUpdate {
    let version: String
    let name: String
    let dmgAsset: GitHubAsset?
    let publishedAt: String
    
    var dmgURL: URL? {
        guard let asset = dmgAsset else { return nil }
        return URL(string: asset.downloadUrl)
    }
}

enum UpdateError: LocalizedError {
    case invalidURL
    case networkError(String)
    case apiError(String)
    case noReleasesPublished
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .noReleasesPublished:
            return "No releases available (development mode)"
        case .decodingError:
            return "Failed to parse update information"
        }
    }
}
