import Foundation
import LimitsCore

final class PlanChecks {
    private let now = Date(timeIntervalSince1970: 1800000000)
    private func fixture(_ name: String) throws -> Usage {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(Usage.self, from: Data(contentsOf: folder.appendingPathComponent("Fixtures/\(name).json")))
    }
    private func sample(_ json: String) throws -> Usage { try JSONDecoder().decode(Usage.self, from: Data(json.utf8)) }
    private func check(_ value: Bool, _ message: String) { guard value else { fatalError(message) } }

    func plusTwoWindows() throws {
        let usage = try fixture("plus")
        check(usage.planLabel == "PLUS", "Plus must be detected")
        check(usage.mainWindows.map(\.windowDurationMins) == [300, 10080], "Both periods required")
        check(usage.statusTitle(at: now, stale: false) == "GPT 5ч 65%/2ч · 7д 32%/5д · ↻1", "Both balances and reset times must be visible")
    }
    func proSingleWindow() throws {
        let usage = try fixture("pro")
        check(usage.planLabel == "PRO", "Pro must be detected")
        check(usage.windowCount == 1, "Do not invent a five-hour window for Pro")
        check(usage.statusTitle(at: now, stale: false) == "GPT 72% · 4д · ↻2", "Keep compact Pro layout")
    }
    func noFixedPlanEntitlements() throws {
        let usage = try sample(#"{"rateLimits":{"planType":"plus","primary":{"usedPercent":5,"windowDurationMins":60,"resetsAt":1800003600}},"rateLimitResetCredits":null}"#)
        check(usage.windowCount == 1, "Do not synthesize missing weekly allowance")
        check(usage.mainWindows[0].shortLabel == "1ч", "Use the service duration")
        check(usage.resetCount == nil, "Unavailable reset bank is not zero")
        let unknown = try sample(#"{"rateLimits":{"planType":"future-plan","primary":null}}"#)
        check(unknown.planLabel == "FUTURE-PLAN", "Unknown plans remain usable")
    }
    func anyExpiredWindowRefreshes() throws {
        let usage = try fixture("plus")
        let later = now.addingTimeInterval(7201)
        check(usage.headline?.windowDurationMins == 10080, "Weekly is most depleted in fixture")
        check(usage.needsResetRefresh(at: later), "Expired short period must trigger refresh too")
        check(usage.statusTitle(at: later, stale: false).contains("5ч —/↻"), "Do not assume a refilled short limit")
    }
    func planChangeRebaselinesAlerts() throws {
        var tracker = AlertTracker()
        _ = tracker.observe(try fixture("pro"), at: now)
        let changed = try sample(#"{"rateLimits":{"planType":"plus","primary":{"usedPercent":0,"windowDurationMins":10080,"resetsAt":1800500000}},"rateLimitResetCredits":{"availableCount":5,"credits":null}}"#)
        check(tracker.observe(changed, at: now.addingTimeInterval(60)).isEmpty, "A plan change is not a quota reset or earned grant")
        check(tracker.planType == "plus", "Remember detected plan")
    }
    func independentPlusResets() throws {
        var tracker = AlertTracker()
        _ = tracker.observe(try fixture("plus"), at: now)
        let changed = try sample(#"{"rateLimits":{"planType":"plus","primary":{"usedPercent":0,"windowDurationMins":300,"resetsAt":1800025200},"secondary":{"usedPercent":68,"windowDurationMins":10080,"resetsAt":1800432000}}}"#)
        let events = tracker.observe(changed, at: now.addingTimeInterval(7201))
        check(events.count == 1 && events[0].kind == .limitReset && events[0].body.contains("5 ч"), "Only the short period reset")
    }
    func oldNotificationStateMigrates() throws {
        let data = Data(#"{"windows":{},"seenCreditIDs":[]}"#.utf8)
        var tracker = try JSONDecoder().decode(AlertTracker.self, from: data)
        check(tracker.observe(try fixture("plus"), at: now).isEmpty, "Version 1.1 state must decode")
    }
}
