//
//  FeedbackManager.swift
//  Default Tamer
//
//  Submits user feedback to Inbounce.
//  Rate limit: once per 24 hours, resets when the app version changes.
//

import Foundation

enum FeedbackError: LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case rateLimited(Date)

    var errorDescription: String? {
        switch self {
        case .networkError(let e): return e.localizedDescription
        case .serverError(let code): return "Server returned \(code). Please try again."
        case .rateLimited: return nil  // handled in UI
        }
    }
}

struct FeedbackManager {
    private static let defaults = UserDefaults.standard
    private static let lastSubmitDateKey    = "feedback.lastSubmitDate"
    private static let lastSubmitVersionKey = "feedback.lastSubmitVersion"
    private static let cooldown: TimeInterval = 86400 // 24 hours

    /// `nil` means feedback is allowed. Non-nil returns the earliest time it's allowed again.
    static var nextAllowedDate: Date? {
        guard let last = defaults.object(forKey: lastSubmitDateKey) as? Date,
              let version = defaults.string(forKey: lastSubmitVersionKey) else { return nil }
        // Reset if user is on a newer version than when they last submitted
        guard !isNewerVersion(AppVersion.current, than: version) else { return nil }
        let next = last.addingTimeInterval(cooldown)
        return next > Date() ? next : nil
    }

    /// Returns true if `a` is strictly greater than `b` using semantic versioning.
    private static func isNewerVersion(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let length = max(aParts.count, bParts.count)
        for i in 0..<length {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }

    static func submit(name: String, rating: Double, comment: String) async throws {
        if let next = nextAllowedDate {
            throw FeedbackError.rateLimited(next)
        }

        let installID = PersistenceManager.shared.installID

        var request = URLRequest(url: URL(string: FeedbackConfig.submitURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let payload: [String: Any] = [
            "name":       name.trimmingCharacters(in: .whitespaces),
            "version":    AppVersion.current,
            "install_id": installID,
            "rating":     rating,
            "comment":    comment.trimmingCharacters(in: .whitespaces),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw FeedbackError.serverError(http.statusCode)
            }
            // Record successful submission
            defaults.set(Date(), forKey: lastSubmitDateKey)
            defaults.set(AppVersion.current, forKey: lastSubmitVersionKey)
        } catch let error as FeedbackError {
            throw error
        } catch {
            throw FeedbackError.networkError(error)
        }
    }
}
