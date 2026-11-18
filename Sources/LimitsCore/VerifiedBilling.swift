import Foundation
import CryptoKit

/// A dated observation of the subscription page, not an automatic billing feed.
/// Store only this projection locally; never store browser credentials or invoices.
public struct VerifiedBilling: Codable, Equatable {
    public let accountFingerprint: String
    public let planType: String
    public let renewalDay: String
    public let checkedAt: Double
    public let source: String

    private static var storageURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ChatGPT Limits/verified-billing.json")
    }

    private static func stored() -> VerifiedBilling? {
        let url = storageURL
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4096,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VerifiedBilling.self, from: data)
    }

    public static func load(accountID: String?, plan: String?, now: Date) -> VerifiedBilling? {
        guard let snapshot = stored(), snapshot.matches(accountID: accountID, plan: plan, now: now) else { return nil }
        return snapshot
    }

    static func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public static func refreshDue(at now: Date) throws -> Bool {
        guard let snapshot = stored(), !snapshot.needsVerification(at: now),
              (snapshot.daysRemaining(at: now) ?? 0) > 0 else { return true }
        let usage = try LimitsReader.fetch()
        return !snapshot.matches(accountID: usage.accountId, plan: usage.planType, now: now)
            || now.timeIntervalSince1970 - snapshot.checkedAt >= 6 * 86400
    }

    public static func sync(renewalDay: String, emailFingerprint: String, plan: String, at now: Date) throws {
        guard let date = parseDay(renewalDay),
              date >= Calendar(identifier: .gregorian).startOfDay(for: now),
              emailFingerprint.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              plan.range(of: "^[a-z0-9_]{1,30}$", options: .regularExpression) != nil else {
            throw LimitsError.malformed
        }
        let usage = try LimitsReader.fetchBillingUsage(emailFingerprint: emailFingerprint, plan: plan)
        guard let accountID = usage.accountId, !accountID.isEmpty, usage.planType == plan else {
            throw LimitsError.authentication
        }
        let snapshot = VerifiedBilling(accountFingerprint: fingerprint(accountID), planType: plan,
                                       renewalDay: renewalDay, checkedAt: now.timeIntervalSince1970,
                                       source: "chatgpt-settings")
        let url = storageURL
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let staging = directory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        guard manager.createFile(atPath: staging.path, contents: try JSONEncoder().encode(snapshot),
                                 attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
        // The private, fully written file replaces the previous snapshot atomically.
        guard rename(staging.path, url.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    public func matches(accountID: String?, plan: String?, now: Date) -> Bool {
        guard let accountID, !accountID.isEmpty, plan == planType,
              source == "chatgpt-settings", checkedAt.isFinite, checkedAt > 0,
              checkedAt <= now.timeIntervalSince1970 + 60, renewalDate != nil else { return false }
        return Self.fingerprint(accountID) == accountFingerprint
    }

    public var renewalDate: Date? { Self.parseDay(renewalDay) }

    private static func parseDay(_ day: String) -> Date? {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.calendar = Calendar(identifier: .gregorian)
        format.dateFormat = "yyyy-MM-dd"
        format.isLenient = false
        guard let date = format.date(from: day), format.string(from: date) == day else { return nil }
        return date
    }

    public func daysRemaining(at now: Date) -> Int? {
        guard let date = renewalDate else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        // Do not invent the following month's date when this observation expires.
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day
    }

    public func needsVerification(at now: Date) -> Bool {
        now.timeIntervalSince1970 - checkedAt >= 7 * 86400 || (daysRemaining(at: now) ?? -1) < 0
    }
}
