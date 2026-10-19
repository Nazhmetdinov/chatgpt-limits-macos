import AppKit
import SwiftUI
import ServiceManagement
import Combine
import LimitsCore
import Darwin

@MainActor
final class UsageModel: ObservableObject {
    @Published var usage: Usage?
    @Published var updatedAt: Date?
    @Published var now = Date()
    @Published var loading = false
    @Published var error: String?
    @Published var loginError: String?
    @Published var browserError: String?
    @Published var verifiedBilling: VerifiedBilling?
    @Published var loginStatus = SMAppService.mainApp.status
    @Published private(set) var fittedPanelHeight: CGFloat = 600
    var isPreview = false
    var panelHeight: CGFloat {
        isPreview ? fittedPanelHeight : min(fittedPanelHeight, (NSScreen.main?.visibleFrame.height ?? 840) - 40)
    }
    func fitPanelToContent() {
        // Measure the same panel without its scroll viewport. Short panels fit
        // their content; only panels taller than the screen need scrolling.
        let view = NSHostingView(rootView: UsagePanel(model: self, intrinsicSize: true))
        let height = ceil(view.fittingSize.height)
        if height > 0, abs(height - fittedPanelHeight) > 0.5 { fittedPanelHeight = height }
    }
    let notifications = NotificationManager()
    private var tick: Timer?
    private var lastAttempt: Date?
    var stale: Bool { error != nil || updatedAt.map { now.timeIntervalSince($0) > 600 } ?? true }
    var title: String { usage?.statusTitle(at: now, stale: stale) ?? (loading ? "GPT …" : "GPT — !") }

    func start() {
        notifications.onChange = { [weak self] in self?.objectWillChange.send() }
        notifications.start()
        if CommandLine.arguments.contains("--test-notification") { notifications.sendTest() }
        refresh()
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickNow() }
        }
        if let tick { RunLoop.main.add(tick, forMode: .common) }
    }
    func tickNow() {
        now = Date()
        notifications.refreshAuthorization()
        let elapsed = lastAttempt.map { now.timeIntervalSince($0) } ?? .infinity
        let expired = usage?.needsResetRefresh(at: now) ?? false
        if elapsed >= 300 || (expired && elapsed >= 60) { refresh() }
    }
    func refresh() {
        guard !loading else { return }
        loading = true
        lastAttempt = Date()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try LimitsReader.fetch() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.now = Date()
                self.loading = false
                switch result {
                case .success(let usage):
                    self.usage = usage
                    self.updatedAt = self.now
                    self.error = nil
                    self.notifications.observe(usage, at: self.now)
                    self.verifiedBilling = VerifiedBilling.load(accountID: usage.accountId, plan: usage.planType, now: self.now)
                case .failure(let failure): self.error = (failure as? LimitsError)?.errorDescription ?? "Не удалось обновить данные."
                }
            }
        }
    }
    func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            else { try SMAppService.mainApp.register() }
            loginError = nil
        } catch { loginError = "Автозапуск: проверьте «Настройки системы → Основные → Объекты входа»." }
        loginStatus = SMAppService.mainApp.status
    }
    func openChatGPT() {
        let candidates = ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
        if let path = candidates.first(where: FileManager.default.fileExists(atPath:)) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init())
        }
    }
    func openSubscription() {
        SubscriptionBrowser.open { [weak self] error in self?.browserError = error }
    }
}

struct UsagePanel: View {
    @ObservedObject var model: UsageModel
    var intrinsicSize = false
    private let accent = Color(red: 0.05, green: 0.60, blue: 0.43)

    private func date(_ timestamp: Double) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "ru_RU")
        format.dateFormat = "d MMM, HH:mm z"
        return format.string(from: Date(timeIntervalSince1970: timestamp))
    }
    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BrandMark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("ChatGPT Limits").font(.system(size: 17, weight: .semibold))
                    caption("Общий лимит ChatGPT Work и Codex")
                }
                Spacer()
                if let plan = model.usage?.planLabel {
                    Text(plan).font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(accent.opacity(0.12), in: Capsule()).foregroundStyle(accent)
                }
            }

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = model.loginError { caption(error) }
            if let error = model.browserError { caption(error) }

            if intrinsicSize {
                cards
            } else {
                ScrollView { cards }.frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 5) {
                if model.isPreview { caption("Демонстрация · вымышленные данные") }
                caption("Остаток доступен в %. Точное число токенов не возвращается.")
                HStack(spacing: 5) {
                    Circle().fill(model.stale ? Color.orange : accent).frame(width: 5, height: 5)
                    if let updatedAt = model.updatedAt {
                        caption("\(model.stale ? "Данные устарели · " : "Обновлено ")\(updatedAt.formatted(date: .omitted, time: .shortened)) · каждые 5 мин")
                    } else { caption("Обновление каждые 5 минут") }
                }
            }
            Divider()
            HStack {
                Button { model.refresh() } label: {
                    Label(model.loading ? "Обновляем…" : "Обновить", systemImage: "arrow.clockwise")
                }.disabled(model.loading).keyboardShortcut("r")
                Spacer()
                Button("Открыть ChatGPT") { model.openChatGPT() }
            }.controlSize(.small)
            HStack {
                Button { model.notifications.settings() } label: {
                    Label(model.notifications.statusLabel,
                          systemImage: model.notifications.canNotify ? "bell.badge" : "bell.slash")
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Тест") { model.notifications.sendTest() }
                    .disabled(!model.notifications.canNotify).buttonStyle(.plain).foregroundStyle(.secondary)
            }.font(.system(size: 11))
            if let error = model.notifications.error { caption(error) }
            HStack {
                Button { model.toggleLogin() } label: {
                    Label(model.loginStatus == .requiresApproval ? "Разрешить автозапуск…" : "Запускать при входе",
                          systemImage: model.loginStatus == .enabled ? "checkmark.square.fill" : "square")
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Выйти") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.font(.system(size: 11))
        }
        .padding(20)
        .frame(width: 390, height: intrinsicSize ? nil : model.panelHeight)
        .fixedSize(horizontal: false, vertical: intrinsicSize)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let usage = model.usage {
                ForEach(usage.buckets, id: \.key) { bucket in
                    ForEach(Array(bucket.value.windows.enumerated()), id: \.offset) { _, window in
                        quotaCard(window, bucket: bucket.value.limitName ?? (bucket.key == "codex" ? "" : bucket.key))
                    }
                }
                if usage.buckets.allSatisfy({ $0.value.windows.isEmpty }) {
                    Text("Сервис не вернул данные о лимитах.").font(.callout).foregroundStyle(.secondary)
                }
                resetCard(usage)
            } else {
                VStack(spacing: 12) {
                    if model.loading { ProgressView().controlSize(.small) }
                    Text(model.loading ? "Получаем лимиты…" : "Нет актуальных данных").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 40)
            }
            BillingCard(snapshot: model.verifiedBilling, now: model.now, openSubscription: model.openSubscription)
        }.padding(.vertical, 1)
    }

    private func quotaCard(_ window: UsageWindow, bucket: String) -> some View {
        let expired = window.hasExpired(at: model.now)
        let remaining = window.remaining
        let color = (remaining ?? 100) <= 10 ? Color.orange : accent
        let compact = (model.usage?.windowCount ?? 0) > 1
        return VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(window.label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(expired ? "—" : remaining.map { "\($0)%" } ?? "—")
                            .font(.system(size: compact ? 30 : 40, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("осталось").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !bucket.isEmpty { Text(bucket).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            ProgressView(value: expired ? 0 : Double(remaining ?? 0), total: 100).tint(color)
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "clock").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.resetDate.map { "Сброс: \(Usage.countdown(to: $0, now: model.now))" } ?? "Время сброса неизвестно")
                        .font(.system(size: 12, weight: .medium))
                    if let timestamp = window.resetsAt { caption(date(timestamp)) }
                }
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
    }

    private func resetCard(_ usage: Usage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "gift").font(.system(size: 20)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Начисленные сбросы").font(.system(size: 13, weight: .medium))
                    caption("Доступно для ручного использования")
                }
                Spacer()
                Text(usage.resetCount.map(String.init) ?? "—").font(.system(size: 28, weight: .semibold, design: .rounded))
            }
            if usage.resetCount == nil { caption("Сервис не вернул количество сбросов.") }
            if let credits = usage.rateLimitResetCredits?.credits {
                ForEach(credits, id: \.id) { credit in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(credit.title ?? "Дополнительный сброс").font(.system(size: 12, weight: .medium))
                        if let grantedAt = credit.grantedAt { caption("Начислен: \(date(grantedAt))") }
                        if let expiresAt = credit.expiresAt { caption("Действует до: \(date(expiresAt))") }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let model = UsageModel()
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    var subscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let peers = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.chatgpt-limits")
        if peers.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "ChatGPTLimits"
        if let button = statusItem.button {
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
            button.setAccessibilityLabel("Лимиты ChatGPT")
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 390, height: 560)
        popover.contentViewController = NSHostingController(rootView: UsagePanel(model: model))
        subscription = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        model.notifications.onOpen = { [weak self] in self?.showPopover() }
        if !UserDefaults.standard.bool(forKey: "loginSetupAttempted") || CommandLine.arguments.contains("--enable-login") {
            UserDefaults.standard.set(true, forKey: "loginSetupAttempted")
            if [.notRegistered, .notFound].contains(SMAppService.mainApp.status) { model.toggleLogin() }
        }
        model.start()
        updateStatus()
    }
    func updateStatus() {
        model.fitPanelToContent()
        statusItem.button?.title = model.title
        popover.contentSize = NSSize(width: 390, height: model.panelHeight)
        statusItem.button?.toolTip = "ChatGPT Work / Codex: период — остаток / до сброса · ↻ начисленные сбросы\(model.stale ? "\nДанные ещё не обновлены или устарели" : "")"
        statusItem.button?.setAccessibilityValue(model.title)
        writeDiagnosticsIfRequested()
    }
    // Opt-in local UI smoke check. No account identifiers or credentials are exported.
    func writeDiagnosticsIfRequested() {
        guard let index = CommandLine.arguments.firstIndex(of: "--diagnostics-directory"),
              index + 1 < CommandLine.arguments.count, model.updatedAt != nil, !model.loading else { return }
        let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        let report: [String: Any] = [
            "title": statusItem.button?.title ?? "", "statusItemVisible": statusItem.isVisible,
            "updatedAt": model.updatedAt!.timeIntervalSince1970, "stale": model.stale,
            "loginStatus": model.loginStatus.rawValue, "loginError": model.loginError ?? "",
            "notificationAuthorization": model.notifications.authorization.rawValue,
            "notificationError": model.notifications.error ?? "",
            "pendingNotifications": model.notifications.pendingCount,
            "lastNotification": model.notifications.lastDelivery ?? "",
            "bundlePath": Bundle.main.bundleURL.path
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("status.json"), options: .atomic)
        }
        let view = NSHostingView(rootView: UsagePanel(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 390, height: model.panelHeight)
        view.layoutSubtreeIfNeeded()
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try? bitmap.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("panel.png"))
        }
    }
    @objc func didWake() { model.notifications.refreshAuthorization(); model.refresh() }
    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }
    func showPopover() {
        guard let button = statusItem.button else { return }
        model.now = Date()
        model.loginStatus = SMAppService.mainApp.status
        model.notifications.refreshAuthorization()
        if model.stale { model.refresh() }
        if !popover.isShown { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }
}

signal(SIGPIPE, SIG_IGN)
if let index = CommandLine.arguments.firstIndex(of: "--render-fixture"), index + 2 < CommandLine.arguments.count {
    do {
        try MainActor.assumeIsolated { try renderFixture(input: CommandLine.arguments[index + 1], output: CommandLine.arguments[index + 2]) }
    } catch { fputs("Fixture rendering failed.\n", stderr); exit(1) }
} else if CommandLine.arguments.contains("--login-status") {
    switch SMAppService.mainApp.status {
    case .enabled: print("enabled")
    case .requiresApproval: print("requires-approval")
    case .notRegistered: print("not-registered")
    case .notFound: print("not-found")
    @unknown default: print("unknown")
    }
} else if CommandLine.arguments.contains("--check") {
    do {
        let usage = try LimitsReader.fetch()
        print(usage.statusTitle(at: Date(), stale: false))
        print("Buckets: \(usage.buckets.count); reset credits: \(usage.resetCount.map(String.init) ?? "unknown")")
        if let billing = VerifiedBilling.load(accountID: usage.accountId, plan: usage.planType, now: Date()) {
            print("Verified renewal: \(billing.renewalDay); automatic updates: unavailable")
        }
    } catch {
        fputs("\((error as? LimitsError)?.errorDescription ?? "Не удалось получить данные")\n", stderr)
        exit(1)
    }
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
