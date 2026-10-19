import AppKit

/// Launch URLs through the selected browser, without reading its profile or
/// requesting Automation/Accessibility permissions.
@MainActor
enum SubscriptionBrowser {
    static let url = URL(string: "https://chatgpt.com/settings/billing")!

    static func open(completion: @escaping (String?) -> Void) {
        let workspace = NSWorkspace.shared
        // Resolve the HTTPS browser independently of ChatGPT-specific app links.
        guard let app = workspace.urlForApplication(toOpen: URL(string: "https://example.com")!),
              let bundle = Bundle(url: app) else {
            completion("Не удалось найти браузер по умолчанию.")
            return
        }
        let id = bundle.bundleIdentifier ?? ""
        let chromium = ["com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev",
                        "com.google.Chrome.canary", "org.chromium.Chromium", "com.microsoft.edgemac",
                        "com.brave.Browser", "com.vivaldi.Vivaldi"]
        if chromium.contains(id) || id == "org.mozilla.firefox" || id == "org.mozilla.firefoxdeveloperedition" {
            // Chromium's command-line URL path creates a foreground tab instead
            // of reusing the tab chosen by a macOS open-URL event. Firefox has an
            // explicit new-tab option. The running browser owns profile selection.
            guard let executable = bundle.executableURL else {
                completion("Не удалось запустить браузер по умолчанию.")
                return
            }
            let process = Process()
            process.executableURL = executable
            process.arguments = id.hasPrefix("org.mozilla.") ? ["-new-tab", url.absoluteString] : [url.absoluteString]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                completion(nil)
            } catch {
                completion("Не удалось открыть подписку в браузере. Повторите попытку.")
            }
        } else {
            // Other browsers (including Safari) decide tab vs window according
            // to their own external-link preferences; macOS has no universal tab API.
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            workspace.open([url], withApplicationAt: app, configuration: configuration) { _, error in
                Task { @MainActor in
                    completion(error == nil ? nil : "Не удалось открыть подписку в браузере. Повторите попытку.")
                }
            }
        }
    }
}
