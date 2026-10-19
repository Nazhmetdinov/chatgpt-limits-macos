import Foundation

public struct UsageAlert: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case lowLimit, limitReset, creditGranted, test }
    public let id: String
    public let kind: Kind
    public let title: String
    public let body: String
    public let createdAt: Date
    public let windowKey: String?
    public let windowGeneration: Int?

    public init(kind: Kind, title: String, body: String, createdAt: Date, windowKey: String? = nil, windowGeneration: Int? = nil) {
        id = UUID().uuidString
        self.kind = kind
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.windowKey = windowKey
        self.windowGeneration = windowGeneration
    }
}

public struct AlertTracker: Codable, Sendable {
    private struct WindowState: Codable, Sendable {
        var usedPercent: Double
        var resetsAt: Double?
        var lowNotified: Bool
        var generation: Int
    }
    private var windows: [String: WindowState] = [:]
    private var creditCount: Int?
    private var creditObservedAt: Date?
    private var seenCreditIDs: Set<String> = []
    public private(set) var planType: String?
    public init() {}

    /// Call only with a successful fresh server response, never on a countdown tick.
    public mutating func observe(_ usage: Usage, at now: Date) -> [UsageAlert] {
        if let plan = usage.planType {
            if let previous = planType, previous != plan { self = AlertTracker() }
            planType = plan
        }
        var alerts: [UsageAlert] = []
        for bucket in usage.buckets {
            let slots = [("primary", bucket.value.primary), ("secondary", bucket.value.secondary)]
            for (slot, optionalWindow) in slots {
                guard let window = optionalWindow, let used = window.usedPercent, used.isFinite else { continue }
                let duration = window.windowDurationMins.map(String.init) ?? slot
                let duplicateDuration = bucket.value.windows.filter { $0.windowDurationMins == window.windowDurationMins }.count > 1
                let key = "\(bucket.key):\(duration)\(duplicateDuration ? ":\(slot)" : "")"
                let previous = windows[key]
                let label = bucket.key == "codex" ? window.label : "\(bucket.value.limitName ?? bucket.key) · \(window.label)"
                var reset = false
                if let previous, let oldDeadline = previous.resetsAt, let newDeadline = window.resetsAt {
                    // A moved deadline alone may be a server correction. Require the old
                    // period to have ended, or a simultaneous drop in measured usage.
                    reset = newDeadline > oldDeadline && newDeadline > now.timeIntervalSince1970
                        && (now.timeIntervalSince1970 >= oldDeadline || used < previous.usedPercent)
                }
                var current = WindowState(usedPercent: used, resetsAt: window.resetsAt ?? previous?.resetsAt,
                                          lowNotified: reset ? false : previous?.lowNotified ?? false,
                                          generation: (previous?.generation ?? 0) + (reset ? 1 : 0))
                if reset {
                    alerts.append(UsageAlert(kind: .limitReset, title: "Лимит ChatGPT сбросился",
                        body: "\(label): доступно \(window.remaining.map { "\($0)%" } ?? "новое окно лимита").",
                        createdAt: now, windowKey: key, windowGeneration: current.generation))
                }
                // Strictly below 10%, using the unrounded percentage. Warn once per period,
                // including when the app first discovers an already-low active quota.
                let expired = current.resetsAt.map { $0 <= now.timeIntervalSince1970 } ?? false
                if used > 90, !expired, !current.lowNotified {
                    alerts.append(UsageAlert(kind: .lowLimit, title: "Осталось меньше 10% лимита ChatGPT",
                        body: "\(label): осталось \(window.remaining.map { "\($0)%" } ?? "меньше 10%").",
                        createdAt: now, windowKey: key, windowGeneration: current.generation))
                    current.lowNotified = true
                }
                windows[key] = current
            }
        }
        if let count = usage.resetCount {
            let details = (usage.rateLimitResetCredits?.credits ?? []).filter { $0.status == nil || $0.status == "available" }
            if let previousCount = creditCount, let observedAt = creditObservedAt {
                // Detail rows may be capped or appear late. A new ID is evidence of a
                // grant only when its grant timestamp is newer than our last observation.
                let newGrants = details.filter { credit in
                    guard !seenCreditIDs.contains(credit.id), let granted = credit.grantedAt else { return false }
                    return granted >= floor(observedAt.timeIntervalSince1970) && granted <= now.timeIntervalSince1970
                }.count
                let added = max(count - previousCount, newGrants)
                if added > 0 {
                    alerts.append(UsageAlert(kind: .creditGranted, title: "Начислен дополнительный сброс ChatGPT",
                        body: "Новых сбросов: \(added). Всего доступно: \(count).", createdAt: now))
                }
            }
            creditCount = count
            creditObservedAt = now
            seenCreditIDs.formUnion(details.map(\.id))
        }
        return alerts
    }

    public func isStillRelevant(_ alert: UsageAlert, at now: Date) -> Bool {
        guard now.timeIntervalSince(alert.createdAt) <= 86400 else { return false }
        guard alert.kind == .lowLimit, let key = alert.windowKey else { return true }
        guard let window = windows[key], window.usedPercent > 90 else { return false }
        guard alert.windowGeneration == window.generation else { return false }
        return window.resetsAt.map { $0 > now.timeIntervalSince1970 } ?? true
    }
}
