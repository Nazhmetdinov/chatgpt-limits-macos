import Foundation
import LimitsCore

final class UsageChecks {
    private func decode(_ json: String) throws -> Usage { try JSONDecoder().decode(Usage.self, from: Data(json.utf8)) }
    private func window(_ json: String) throws -> UsageWindow { try JSONDecoder().decode(UsageWindow.self, from: Data(json.utf8)) }

    func testRealPayloadShape() throws {
        let usage = try decode(#"{"rateLimits":{"primary":{"usedPercent":3,"windowDurationMins":10080,"resetsAt":2000000000}},"rateLimitResetCredits":{"availableCount":0,"credits":[]}}"#)
        expectEqual(usage.headline?.remaining, 97)
        expectEqual(usage.headline?.label, "Недельный лимит")
        expectEqual(usage.resetCount, 0)
        expectEqual(usage.statusTitle(at: Date(timeIntervalSince1970: 1999600000), stale: false), "GPT 97% · 4д · ↻0")
    }
    func testUnknownIsNotZero() throws {
        let usage = try decode(#"{"rateLimits":null,"rateLimitsByLimitId":{},"rateLimitResetCredits":null}"#)
        expectNil(usage.resetCount)
        expectNil(usage.headline)
        expectEqual(usage.statusTitle(at: Date(), stale: true), "GPT — · — · ↻— !")
        expectNil(try window(#"{}"#).remaining)
    }
    func testServerCountIsAuthoritativeEvenWithPartialDetails() throws {
        let usage = try decode(#"{"rateLimitResetCredits":{"availableCount":5,"credits":[{"id":"example","status":"available","expiresAt":null,"title":null}]}}"#)
        expectEqual(usage.resetCount, 5)
        expectEqual(usage.rateLimitResetCredits?.credits?.count, 1)
    }
    func testMultiBucketPrecedenceAndMostDepletedWindow() throws {
        let usage = try decode(#"{"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"other":{"primary":{"usedPercent":100}},"codex":{"primary":{"usedPercent":20,"windowDurationMins":300},"secondary":{"usedPercent":75,"windowDurationMins":10080}}}}"#)
        expectEqual(usage.buckets.first?.key, "codex")
        expectEqual(usage.headline?.remaining, 25)
        expectEqual(usage.headline?.windowDurationMins, 10080)
    }
    func testPercentBoundsAndRounding() throws {
        expectEqual(try window(#"{"usedPercent":103}"#).remaining, 0)
        expectEqual(try window(#"{"usedPercent":-5}"#).remaining, 100)
        expectEqual(try window(#"{"usedPercent":3.2}"#).remaining, 96)
    }
    func testResetDeadlineDoesNotInventRefilledQuota() throws {
        let usage = try decode(#"{"rateLimits":{"primary":{"usedPercent":60,"resetsAt":1000}}}"#)
        expectEqual(usage.statusTitle(at: Date(timeIntervalSince1970: 1001), stale: false), "GPT — · ↻ · ↻—")
    }
    func testCountdownBoundaries() {
        let now = Date(timeIntervalSince1970: 1000)
        expectEqual(Usage.countdown(to: now.addingTimeInterval(59), now: now), "<1м")
        expectEqual(Usage.countdown(to: now.addingTimeInterval(3600), now: now), "1 ч 0 мин")
        expectEqual(Usage.countdown(to: now.addingTimeInterval(90000), now: now), "1 д 1 ч")
        expectEqual(Usage.countdown(to: now, now: now), "Ожидаем обновление лимита")
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    guard actual == expected else { fatalError("Expected \(expected), got \(actual)", file: file, line: line) }
}
private func expectNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    guard value == nil else { fatalError("Expected nil", file: file, line: line) }
}

let checks = UsageChecks()
let notifications = NotificationChecks()
let plans = PlanChecks()
let billing = VerifiedBillingChecks()
let cases: [(String, () throws -> Void)] = [
    ("verified billing account isolation", billing.accountIsolation),
    ("verified billing rejects invalid metadata", billing.invalidDatesAndVerification),
    ("verified billing freshness and no rollover", billing.freshnessAndNoRollover),
    ("real payload", checks.testRealPayloadShape),
    ("unknown values", checks.testUnknownIsNotZero),
    ("authoritative reset count", checks.testServerCountIsAuthoritativeEvenWithPartialDetails),
    ("multiple buckets and windows", checks.testMultiBucketPrecedenceAndMostDepletedWindow),
    ("percent bounds", checks.testPercentBoundsAndRounding),
    ("expired quota", checks.testResetDeadlineDoesNotInventRefilledQuota),
    ("countdown boundaries", checks.testCountdownBoundaries),
    ("strict 10% threshold and duplicate suppression", notifications.thresholdAndDuplicateSuppression),
    ("first launch notification baseline", notifications.initialBaseline),
    ("confirmed reset and next low-limit warning", notifications.confirmedResetRearmsWarning),
    ("deadline correction versus manual reset", notifications.correctionsAndManualReset),
    ("restart persistence and unknown samples", notifications.persistedStateAndUnknownSamples),
    ("reset-credit balance changes", notifications.creditBalanceChanges),
    ("grant with unchanged balance and partial details", notifications.grantsWithUnchangedBalanceAndPartialDetails),
    ("independent windows and expired sample", notifications.independentWindowsAndExpiredInitialSample),
    ("obsolete queued warnings", notifications.obsoleteQueuedWarnings),
    ("rollover while app was closed", notifications.rolloverWhileAppWasClosed),
    ("Plus: two visible periods and countdowns", plans.plusTwoWindows),
    ("Pro: no invented short period", plans.proSingleWindow),
    ("server-driven plan parameters", plans.noFixedPlanEntitlements),
    ("refresh after any period expires", plans.anyExpiredWindowRefreshes),
    ("plan-change notification baseline", plans.planChangeRebaselinesAlerts),
    ("independent Plus period resets", plans.independentPlusResets),
    ("notification state migration", plans.oldNotificationStateMigrates)
]
for (name, run) in cases {
    try run()
    print("PASS: \(name)")
}
print("\(cases.count) checks passed")
