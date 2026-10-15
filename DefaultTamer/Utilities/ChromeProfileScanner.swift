//
//  ChromeProfileScanner.swift
//  Default Tamer
//
//  Reads Chrome-family browser profiles from disk.
//

import Foundation
import Darwin
import os.log

private let scannerLog = Logger(subsystem: "com.defaulttamer.app", category: "ChromeProfileScanner")

struct ChromeProfile {
    let directory: String  // e.g. "Default", "Profile 1"
    let name: String       // e.g. "Devendra Pratap Singh", "Test 1"
}

enum ChromeProfileScanner {
    /// Returns the list of profiles for a Chromium-based browser.
    ///
    /// Reads from the browser's `Local State` file, which stores the canonical
    /// human-readable name for each profile under `profile.info_cache`.
    ///
    /// - Parameter profilePath: Path relative to `~/Library/Application Support/`
    ///   where the browser stores its data (e.g. `"Google/Chrome"`).
    ///
    /// Returns an empty array if the browser is not installed or has no profile data.
    /// The real POSIX home directory of the current user.
    /// Inside a macOS sandbox, `FileManager.homeDirectoryForCurrentUser` and
    /// `NSHomeDirectory()` return the container path. `getpwuid` always returns
    /// the actual home regardless of sandbox state.
    private static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static func profiles(forProfilePath profilePath: String) -> [ChromeProfile] {
        let base = realHomeDirectory
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(profilePath)

        scannerLog.info("scanning: \(base.path, privacy: .public)")

        let localStateURL = base.appendingPathComponent("Local State")

        guard FileManager.default.fileExists(atPath: localStateURL.path) else {
            scannerLog.warning("Local State not found at \(localStateURL.path, privacy: .public)")
            return []
        }
        guard let data = try? Data(contentsOf: localStateURL) else {
            scannerLog.error("cannot read Local State at \(localStateURL.path, privacy: .public)")
            return []
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileSection = json["profile"] as? [String: Any],
              let infoCache = profileSection["info_cache"] as? [String: Any]
        else {
            scannerLog.error("failed to parse Local State JSON")
            return []
        }
        scannerLog.info("found \(infoCache.count, privacy: .public) profiles in Local State")

        var profiles: [ChromeProfile] = []

        for (directory, value) in infoCache {
            // Only include standard profile directory names
            guard directory == "Default" || directory.hasPrefix("Profile ") else { continue }
            guard let info = value as? [String: Any] else { continue }

            // Prefer gaia_name (Google account display name), fall back to the profile's local name
            let gaiaName = (info["gaia_name"] as? String) ?? ""
            let localName = (info["name"] as? String) ?? ""
            let displayName = gaiaName.isEmpty ? localName : gaiaName

            guard !displayName.isEmpty else { continue }

            profiles.append(ChromeProfile(directory: directory, name: displayName))
        }

        // Sort: Default first, then Profile 1, Profile 2, …
        return profiles.sorted { a, b in
            if a.directory == "Default" { return true }
            if b.directory == "Default" { return false }
            return a.directory < b.directory
        }
    }
}
