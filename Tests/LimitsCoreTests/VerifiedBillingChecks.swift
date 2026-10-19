import Foundation
import CryptoKit
import LimitsCore

final class VerifiedBillingChecks {
    private func snapshot(day: String = "2027-01-25", checkedAt: Double = 1_800_000_000, source: String = "chatgpt-settings") throws -> VerifiedBilling {
        let fingerprint = SHA256.hash(data: Data("synthetic-account".utf8)).map { String(format: "%02x", $0) }.joined()
        let object: [String: Any] = ["accountFingerprint": fingerprint, "planType": "pro", "renewalDay": day, "checkedAt": checkedAt, "source": source]
        return try JSONDecoder().decode(VerifiedBilling.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func accountIsolation() throws {
        let value = try snapshot(), now = Date(timeIntervalSince1970: 1_800_000_000)
        precondition(value.matches(accountID: "synthetic-account", plan: "pro", now: now))
        precondition(!value.matches(accountID: "another-account", plan: "pro", now: now))
        precondition(!value.matches(accountID: nil, plan: "pro", now: now))
        precondition(!value.matches(accountID: "synthetic-account", plan: "plus", now: now))
    }
    func invalidDatesAndVerification() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let invalidDay = try snapshot(day: "2027-02-30"), invalidText = try snapshot(day: "not-a-date")
        let future = try snapshot(checkedAt: 1_800_001_000), unknownSource = try snapshot(source: "unknown")
        precondition(invalidDay.renewalDate == nil)
        precondition(invalidText.renewalDate == nil)
        precondition(!future.matches(accountID: "synthetic-account", plan: "pro", now: now))
        precondition(!unknownSource.matches(accountID: "synthetic-account", plan: "pro", now: now))
    }
    func freshnessAndNoRollover() throws {
        let value = try snapshot(), now = Date(timeIntervalSince1970: 1_800_000_000)
        precondition(!value.needsVerification(at: now))
        precondition(value.needsVerification(at: now.addingTimeInterval(86400)))
        let after = value.renewalDate!.addingTimeInterval(86400)
        precondition(value.daysRemaining(at: after) == -1)
        precondition(value.needsVerification(at: after))
        precondition(value.renewalDay == "2027-01-25")
    }
}
