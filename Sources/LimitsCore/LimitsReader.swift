import Foundation
import Darwin

public enum LimitsError: Error, LocalizedError {
    case missingCLI, launch, disconnected, timeout, authentication, request, malformed
    public var errorDescription: String? {
        switch self {
        case .missingCLI: return "Установите ChatGPT или Codex на этом Mac."
        case .launch: return "Не удалось запустить службу ChatGPT."
        case .disconnected: return "Служба ChatGPT завершила соединение."
        case .timeout: return "Нет ответа. Проверьте подключение к интернету."
        case .authentication: return "Откройте ChatGPT и войдите в аккаунт."
        case .request: return "Не удалось получить лимиты. Проверьте сеть и вход в ChatGPT."
        case .malformed: return "Формат данных изменился. Требуется обновление индикатора."
        }
    }
}

public enum LimitsReader {
    public static func executable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex"
        ]
        return paths.first(where: FileManager.default.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
    }

    // Uses the installed client's login; never reads, copies or logs credentials.
    // Only initialize and account/rateLimits/read are sent. No inference or reset redemption.
    public static func fetch(timeout: TimeInterval = 30) throws -> Usage {
        guard let executable = executable() else { throw LimitsError.missingCLI }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://", "-c", "analytics.enabled=false"]
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw LimitsError.launch }
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        defer {
            try? input.fileHandleForWriting.close()
            let deadline = ProcessInfo.processInfo.systemUptime + 0.5
            while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.01) }
            if process.isRunning { process.terminate() }
            let terminateDeadline = ProcessInfo.processInfo.systemUptime + 0.5
            while process.isRunning && ProcessInfo.processInfo.systemUptime < terminateDeadline { Thread.sleep(forTimeInterval: 0.01) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            try? output.fileHandleForReading.close()
        }
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": [
            "name": "chatgpt_limits_menu", "title": "ChatGPT Limits", "version": "1.3.6"
        ]]])
        var buffer = Data(), initialized = false
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 200)
            if ready < 0 { if errno == EINTR { continue }; throw LimitsError.disconnected }
            if ready == 0 { continue }
            var bytes = [UInt8](repeating: 0, count: 8192)
            let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
            guard count > 0 else { throw LimitsError.disconnected }
            buffer.append(contentsOf: bytes.prefix(count))
            guard buffer.count < 2_000_000 else { throw LimitsError.malformed }
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let id = message["id"] as? Int, id == 1 || id == 2 else { continue }
                if let error = message["error"] as? [String: Any] {
                    let text = (error["message"] as? String ?? "").lowercased()
                    if ["401", "unauthorized", "not authenticated", "sign in", "authentication", "not logged"].contains(where: text.contains) {
                        throw LimitsError.authentication
                    }
                    throw LimitsError.request
                }
                if id == 1 && !initialized {
                    initialized = true
                    try send(["method": "initialized", "params": [:]])
                    try send(["id": 2, "method": "account/rateLimits/read", "params": [:]])
                } else if id == 2, initialized, let result = message["result"] as? [String: Any] {
                    do { return try JSONDecoder().decode(Usage.self, from: JSONSerialization.data(withJSONObject: result)) }
                    catch { throw LimitsError.malformed }
                }
            }
        }
        throw LimitsError.timeout
    }
}
