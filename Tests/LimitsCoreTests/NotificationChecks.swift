import Foundation
import LimitsCore

final class NotificationChecks {
    private func usage(_ used: Double? = 20, deadline: Double? = 2000, count: Int? = nil,
                       credits: [[String: Any]]? = nil) throws -> Usage {
        let value: [String: Any] = [
            "rateLimits": ["primary": ["usedPercent": used as Any? ?? NSNull(),
                                         "resetsAt": deadline as Any? ?? NSNull(), "windowDurationMins": 10080]],
            "rateLimitResetCredits": count.map { ["availableCount": $0, "credits": credits as Any? ?? NSNull()] } as Any? ?? NSNull()
        ]
        return try JSONDecoder().decode(Usage.self, from: JSONSerialization.data(withJSONObject: value))
    }
    private func at(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }
    private func kinds(_ events: [UsageAlert]) -> [UsageAlert.Kind] { events.map(\.kind) }
    private func expect(_ actual: [UsageAlert.Kind], _ expected: [UsageAlert.Kind]) {
        guard actual == expected else { fatalError("Expected \(expected), got \(actual)") }
    }

    func thresholdAndDuplicateSuppression() throws {
        var tracker = AlertTracker()
        expect(kinds(tracker.observe(try usage(90), at: at(1000))), [])
        expect(kinds(tracker.observe(try usage(90.01), at: at(1010))), [.lowLimit])
        expect(kinds(tracker.observe(try usage(99), at: at(1020))), [])
        expect(kinds(tracker.observe(try usage(80), at: at(1030))), [])
        expect(kinds(tracker.observe(try usage(95), at: at(1040))), [])
    }
    func initialBaseline() throws {
        var tracker = AlertTracker()
        expect(kinds(tracker.observe(try usage(20, count: 4), at: at(1000))), [])
        expect(kinds(tracker.observe(try usage(95, count: 4), at: at(1010))), [.lowLimit])
        var alreadyLow = AlertTracker()
        expect(kinds(alreadyLow.observe(try usage(95), at: at(1000))), [.lowLimit])
    }
    func confirmedResetRearmsWarning() throws {
        var tracker = AlertTracker()
        expect(kinds(tracker.observe(try usage(95), at: at(1000))), [.lowLimit])
        expect(kinds(tracker.observe(try usage(95), at: at(2001))), [])
        expect(kinds(tracker.observe(try usage(0, deadline: 3000), at: at(2010))), [.limitReset])
        expect(kinds(tracker.observe(try usage(0, deadline: 3000), at: at(2020))), [])
        expect(kinds(tracker.observe(try usage(95, deadline: 3000), at: at(2030))), [.lowLimit])
    }
    func correctionsAndManualReset() throws {
        var tracker = AlertTracker()
        _ = tracker.observe(try usage(70), at: at(1000))
        expect(kinds(tracker.observe(try usage(70, deadline: 2100), at: at(1010))), [])
        expect(kinds(tracker.observe(try usage(0, deadline: 3000), at: at(1020))), [.limitReset])
        var noDeadline = AlertTracker()
        _ = noDeadline.observe(try usage(70, deadline: nil), at: at(1000))
        expect(kinds(noDeadline.observe(try usage(0, deadline: nil), at: at(1010))), [])
    }
    func persistedStateAndUnknownSamples() throws {
        var tracker = AlertTracker()
        _ = tracker.observe(try usage(95, count: 2), at: at(1000))
        let saved = try JSONEncoder().encode(tracker)
        tracker = try JSONDecoder().decode(AlertTracker.self, from: saved)
        expect(kinds(tracker.observe(try usage(nil, count: nil), at: at(1010))), [])
        expect(kinds(tracker.observe(try usage(95, count: 2), at: at(1020))), [])
        expect(kinds(tracker.observe(try usage(95, count: 3), at: at(1030))), [.creditGranted])
    }
    func creditBalanceChanges() throws {
        var tracker = AlertTracker()
        _ = tracker.observe(try usage(count: 0), at: at(1000))
        expect(kinds(tracker.observe(try usage(count: 2), at: at(1010))), [.creditGranted])
        expect(kinds(tracker.observe(try usage(count: 2), at: at(1020))), [])
        expect(kinds(tracker.observe(try usage(count: 1), at: at(1030))), [])
        expect(kinds(tracker.observe(try usage(count: 2), at: at(1040))), [.creditGranted])
    }
    func grantsWithUnchangedBalanceAndPartialDetails() throws {
        var tracker = AlertTracker()
        let old: [[String: Any]] = [["id": "a", "grantedAt": 900, "status": "available"]]
        let fresh: [[String: Any]] = [["id": "b", "grantedAt": 1005, "status": "available"]]
        _ = tracker.observe(try usage(count: 1, credits: old), at: at(1000))
        expect(kinds(tracker.observe(try usage(count: 1, credits: fresh), at: at(1010))), [.creditGranted])
        expect(kinds(tracker.observe(try usage(count: 1, credits: nil), at: at(1020))), [])
        expect(kinds(tracker.observe(try usage(count: 1, credits: fresh), at: at(1030))), [])
        let late: [[String: Any]] = [["id": "c", "grantedAt": 800, "status": "available"]]
        expect(kinds(tracker.observe(try usage(count: 1, credits: late), at: at(1040))), [])
    }
    func independentWindowsAndExpiredInitialSample() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":95,"windowDurationMins":300,"resetsAt":2000},"secondary":{"usedPercent":96,"windowDurationMins":10080,"resetsAt":3000}}}"#.utf8)
        let sample = try JSONDecoder().decode(Usage.self, from: data)
        var tracker = AlertTracker()
        expect(kinds(tracker.observe(sample, at: at(1000))), [.lowLimit, .lowLimit])
        expect(kinds(tracker.observe(sample, at: at(1100))), [])
        var expired = AlertTracker()
        expect(kinds(expired.observe(try usage(99, deadline: 900), at: at(1000))), [])
    }
    func obsoleteQueuedWarnings() throws {
        var tracker = AlertTracker()
        let old = tracker.observe(try usage(95), at: at(1000))[0]
        guard tracker.isStillRelevant(old, at: at(1001)) else { fatalError("Fresh warning dropped") }
        _ = tracker.observe(try usage(0, deadline: 3000), at: at(2010))
        _ = tracker.observe(try usage(95, deadline: 3000), at: at(2020))
        guard !tracker.isStillRelevant(old, at: at(2021)) else { fatalError("Old-period warning retained") }
        let event = UsageAlert(kind: .creditGranted, title: "fixture", body: "fixture", createdAt: at(1000))
        guard !tracker.isStillRelevant(event, at: at(90000)) else { fatalError("Old event retained") }
    }
    func rolloverWhileAppWasClosed() throws {
        var tracker = AlertTracker()
        _ = tracker.observe(try usage(40), at: at(1000))
        expect(kinds(tracker.observe(try usage(95, deadline: 4000), at: at(3500))), [.limitReset, .lowLimit])
    }
}
