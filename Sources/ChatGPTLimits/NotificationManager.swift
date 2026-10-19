import AppKit
import UserNotifications
import CryptoKit
import LimitsCore

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private struct State: Codable {
        var tracker = AlertTracker()
        var pending: [UsageAlert] = []
        var accountFingerprint: String?
    }
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let stateKey = "notificationState.v1"
    private var state: State
    private var inFlight: Set<String> = []
    private var requestingPermission = false
    private var hasFreshUsage = false
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var error: String?
    private(set) var lastDelivery: String?
    var onChange: (() -> Void)?
    var onOpen: (() -> Void)?
    var canNotify: Bool { authorization == .authorized || authorization == .provisional }
    var pendingCount: Int { state.pending.count }
    var statusLabel: String {
        if error != nil { return "Уведомления: нужна проверка" }
        switch authorization {
        case .authorized, .provisional: return "Уведомления включены"
        case .denied: return "Разрешить уведомления…"
        default: return requestingPermission ? "Ожидаем разрешение macOS…" : "Включить уведомления…"
        }
    }

    override init() {
        if let data = UserDefaults.standard.data(forKey: "notificationState.v1"),
           let saved = try? JSONDecoder().decode(State.self, from: data) { state = saved }
        else { state = State() }
        super.init()
    }

    func start() {
        center.delegate = self
        refreshAuthorization(requestIfNeeded: true)
    }

    func refreshAuthorization(requestIfNeeded: Bool = false) {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                self.authorization = settings.authorizationStatus
                self.onChange?()
                if settings.authorizationStatus == .notDetermined, requestIfNeeded, !self.requestingPermission {
                    self.requestingPermission = true
                    self.onChange?()
                    self.center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, failure in
                        Task { @MainActor in
                            guard let self else { return }
                            self.requestingPermission = false
                            self.error = failure == nil ? nil : "macOS не разрешила уведомления. Проверьте настройки уведомлений."
                            self.refreshAuthorization()
                        }
                    }
                } else if self.canNotify {
                    self.flush()
                } else if self.authorization == .denied {
                    self.state.pending.removeAll()
                    self.save()
                }
            }
        }
    }

    func observe(_ usage: Usage, at now: Date) {
        hasFreshUsage = true
        if let plan = usage.planType, let previous = state.tracker.planType, plan != previous {
            state.pending.removeAll { $0.kind != .test }
        }
        // Scope state when the service supplies an account identity. Only its hash is saved.
        if let account = usage.accountId {
            let fingerprint = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
            if state.accountFingerprint != fingerprint {
                state = State(pending: state.pending.filter { $0.kind == .test }, accountFingerprint: fingerprint)
            }
        }
        let events = state.tracker.observe(usage, at: now)
        if authorization != .denied { state.pending.append(contentsOf: events) }
        let tracker = state.tracker
        state.pending.removeAll { !tracker.isStillRelevant($0, at: now) }
        state.pending = Array(state.pending.suffix(64))
        save()
        flush()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: stateKey) }
    }

    private func acknowledge(_ id: String) {
        inFlight.remove(id)
        state.pending.removeAll { $0.id == id }
        save()
        onChange?()
    }

    private func flush() {
        guard canNotify else { return }
        let tracker = state.tracker
        state.pending.removeAll { !tracker.isStillRelevant($0, at: Date()) }
        save()
        let events = state.pending.filter { !inFlight.contains($0.id) && (hasFreshUsage || $0.kind == .test) }
        guard !events.isEmpty else { return }
        inFlight.formUnion(events.map(\.id))
        // Avoid replaying a delivered event after a crash between delivery and saving state.
        center.getDeliveredNotifications { [weak self] delivered in
            let deliveredIDs = Set(delivered.map { $0.request.identifier })
            Task { @MainActor in
                guard let self else { return }
                for event in events {
                    guard self.state.pending.contains(where: { $0.id == event.id }) else {
                        self.inFlight.remove(event.id); continue
                    }
                    if deliveredIDs.contains(event.id) { self.acknowledge(event.id); continue }
                    let content = UNMutableNotificationContent()
                    content.title = event.title
                    content.body = event.body
                    content.sound = .default
                    content.threadIdentifier = "chatgpt-limits"
                    self.center.add(UNNotificationRequest(identifier: event.id, content: content, trigger: nil)) { [weak self] failure in
                        Task { @MainActor in
                            guard let self else { return }
                            if failure == nil {
                                self.lastDelivery = event.kind.rawValue
                                self.error = nil
                                self.acknowledge(event.id)
                            } else {
                                self.inFlight.remove(event.id)
                                self.error = "Не удалось показать уведомление. Повторим при обновлении."
                                self.onChange?()
                            }
                        }
                    }
                }
            }
        }
    }

    func settings() {
        if authorization == .notDetermined { refreshAuthorization(requestIfNeeded: true) }
        else if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=local.chatgpt-limits") {
            NSWorkspace.shared.open(url)
        }
    }

    func sendTest() {
        state.pending.append(UsageAlert(kind: .test, title: "Уведомления ChatGPT Limits работают",
            body: "Это тест. Уведомим при остатке ниже 10%, сбросе лимита и начислении дополнительного сброса.", createdAt: Date()))
        save()
        refreshAuthorization(requestIfNeeded: true)
    }

    func configurePreview() { authorization = .authorized }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                           withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in self.onOpen?() }
        completionHandler()
    }
}
