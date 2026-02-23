import Foundation

// GitHub API release response structure
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let draft: Bool
    let prerelease: Bool
    let publishedAt: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case draft
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
    
    var version: String {
        // Remove 'v' prefix if present (v0.0.2 → 0.0.2)
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

struct GitHubAsset: Codable {
    let name: String
    let downloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case downloadUrl = "browser_download_url"
    }
    
    var isDMG: Bool {
        name.lowercased().hasSuffix(".dmg")
    }
}
