import Foundation

public struct UsageWindow: Decodable, Sendable {
    public let usedPercent: Double?
    public let windowDurationMins: Int?
    public let resetsAt: Double?

    public var remaining: Int? {
        guard let usedPercent, usedPercent.isFinite else { return nil }
        return Int(max(0, min(100, 100 - usedPercent)).rounded(.down))
    }
    public var resetDate: Date? { resetsAt.map(Date.init(timeIntervalSince1970:)) }
    public var shortLabel: String {
        guard let minutes = windowDurationMins, minutes > 0 else { return "лимит" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)д" }
        if minutes % 60 == 0 { return "\(minutes / 60)ч" }
        return "\(minutes)м"
    }
    public var label: String {
        guard let minutes = windowDurationMins, minutes > 0 else { return "Лимит" }
        if minutes == 10080 { return "Недельный лимит" }
        if minutes == 1440 { return "Суточный лимит" }
        if minutes % 1440 == 0 { return "Лимит на \(minutes / 1440) д" }
        if minutes % 60 == 0 { return "Лимит на \(minutes / 60) ч" }
        return "Лимит на \(minutes) мин"
    }
    public func hasExpired(at now: Date) -> Bool { resetDate.map { $0 <= now } ?? false }
}

public struct QuotaBucket: Decodable, Sendable {
    public let limitId: String?
    public let limitName: String?
    public let primary: UsageWindow?
    public let secondary: UsageWindow?
    public let planType: String?
    public var windows: [UsageWindow] { [primary, secondary].compactMap { $0 } }
}

public struct ResetCredit: Decodable, Sendable {
    public let id: String
    public let status: String?
    public let grantedAt: Double?
    public let expiresAt: Double?
    public let title: String?
}

public struct ResetBank: Decodable, Sendable {
    public let availableCount: Int?
    public let credits: [ResetCredit]?
}

public struct Usage: Decodable, Sendable {
    public let accountId: String?
    public let rateLimits: QuotaBucket?
    public let rateLimitsByLimitId: [String: QuotaBucket]?
    public let rateLimitResetCredits: ResetBank?

    public var planType: String? {
        let value = buckets.compactMap(\.value.planType).first ?? rateLimits?.planType
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value.lowercased()
    }
    public var planLabel: String? { planType?.uppercased() }
    public var mainWindows: [UsageWindow] {
        (buckets.first?.value.windows ?? []).sorted { ($0.windowDurationMins ?? .max) < ($1.windowDurationMins ?? .max) }
    }
    public var windowCount: Int { buckets.reduce(0) { $0 + $1.value.windows.count } }
    public func needsResetRefresh(at now: Date) -> Bool {
        buckets.contains { $0.value.windows.contains { $0.hasExpired(at: now) } }
    }

    public var buckets: [(key: String, value: QuotaBucket)] {
        if let map = rateLimitsByLimitId, !map.isEmpty {
            return map.sorted { a, b in
                if a.key == "codex" { return b.key != "codex" }
                if b.key == "codex" { return false }
                return a.key < b.key
            }
        }
        return rateLimits.map { [(key: $0.limitId ?? "codex", value: $0)] } ?? []
    }

    // Prefer the shared Codex bucket, then its most depleted window.
    public var headline: UsageWindow? {
        guard let bucket = buckets.first?.value else { return nil }
        return bucket.windows.min {
            if $0.remaining == $1.remaining {
                return ($0.resetsAt ?? .greatestFiniteMagnitude) < ($1.resetsAt ?? .greatestFiniteMagnitude)
            }
            return ($0.remaining ?? 101) < ($1.remaining ?? 101)
        }
    }
    public var resetCount: Int? {
        guard let count = rateLimitResetCredits?.availableCount, count >= 0 else { return nil }
        return count
    }
    public func statusTitle(at now: Date, stale: Bool) -> String {
        if mainWindows.count > 1 {
            let parts = mainWindows.map { window -> String in
                let percent = !window.hasExpired(at: now) ? window.remaining.map { "\($0)%" } ?? "—" : "—"
                let countdown = window.resetDate.map { Self.countdown(to: $0, now: now, compact: true) } ?? "—"
                return "\(window.shortLabel) \(percent)/\(countdown)"
            }
            return "GPT \(parts.joined(separator: " · ")) · ↻\(resetCount.map(String.init) ?? "—")\(stale ? " !" : "")"
        }
        let percent: String
        if let headline, !headline.hasExpired(at: now), let remaining = headline.remaining {
            percent = "\(remaining)%"
        } else { percent = "—" }
        let countdown = headline?.resetDate.map { Self.countdown(to: $0, now: now, compact: true) } ?? "—"
        return "GPT \(percent) · \(countdown) · ↻\(resetCount.map(String.init) ?? "—")\(stale ? " !" : "")"
    }
    public static func countdown(to deadline: Date, now: Date, compact: Bool = false) -> String {
        let seconds = deadline.timeIntervalSince(now)
        guard seconds > 0 else { return compact ? "↻" : "Ожидаем обновление лимита" }
        if seconds < 60 { return "<1м" }
        let minutes = Int(seconds / 60)
        let days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return compact ? "\(days)д" : "\(days) д \(hours) ч" }
        if minutes >= 60 { return compact ? "\(minutes / 60)ч" : "\(minutes / 60) ч \(minutes % 60) мин" }
        return compact ? "\(minutes)м" : "\(minutes) мин"
    }
}
