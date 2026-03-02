import Foundation

/// Response model for https://www.defaulttamer.app/api/version.json
/// Used only for informational display; actual updates are handled by Sparkle.
struct WebVersionResponse: Codable {
    let version: String
    let releaseDate: String
    let downloadUrl: String
    let releaseNotesUrl: String
}
