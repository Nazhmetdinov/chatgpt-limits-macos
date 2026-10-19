import Foundation
import CryptoKit

/// A dated observation of the subscription page, not an automatic billing feed.
/// Store only this projection locally; never store browser credentials or invoices.
public struct VerifiedBilling: Codable {
    public let accountFingerprint: String
    public let planType: String
    public let renewalDay: String
    public let checkedAt: Double
    public let source: String

    public static func load(accountID: String?, plan: String?, now: Date) -> VerifiedBilling? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ChatGPT Limits/verified-billing.json")
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4096,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(VerifiedBilling.self, from: data),
              snapshot.matches(accountID: accountID, plan: plan, now: now) else { return nil }
        return snapshot
    }

    public func matches(accountID: String?, plan: String?, now: Date) -> Bool {
        guard let accountID, !accountID.isEmpty, plan == planType,
              source == "chatgpt-settings", checkedAt.isFinite, checkedAt > 0,
              checkedAt <= now.timeIntervalSince1970 + 60, renewalDate != nil else { return false }
        let fingerprint = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        return fingerprint == accountFingerprint
    }

    public var renewalDate: Date? {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.calendar = Calendar(identifier: .gregorian)
        format.dateFormat = "yyyy-MM-dd"
        format.isLenient = false
        guard let date = format.date(from: renewalDay), format.string(from: date) == renewalDay else { return nil }
        return date
    }

    public func daysRemaining(at now: Date) -> Int? {
        guard let date = renewalDate else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        // Do not invent the following month's date when this observation expires.
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day
    }

    public func needsVerification(at now: Date) -> Bool {
        now.timeIntervalSince1970 - checkedAt >= 86400 || (daysRemaining(at: now) ?? -1) < 0
    }
}
