import AppKit
import SwiftUI
import LimitsCore

/// Renders only an explicitly supplied synthetic fixture. No login, network,
/// notifications, login-item registration, or preference writes take place.
@MainActor
func renderFixture(input: String, output: String) throws {
    _ = NSApplication.shared
    let data = try Data(contentsOf: URL(fileURLWithPath: input))
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let timestamp = object?["referenceTime"] as? Double else {
        throw NSError(domain: "Preview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture requires referenceTime"])
    }
    let model = UsageModel()
    model.usage = try JSONDecoder().decode(Usage.self, from: data)
    model.now = Date(timeIntervalSince1970: timestamp)
    model.updatedAt = model.now
    model.isPreview = true
    model.loginStatus = .enabled
    model.notifications.configurePreview()
    if let billing = object?["verifiedBilling"],
       let data = try? JSONSerialization.data(withJSONObject: billing) {
        model.verifiedBilling = try JSONDecoder().decode(VerifiedBilling.self, from: data)
    }
    model.fitPanelToContent()
    let view = NSHostingView(rootView: UsagePanel(model: model))
    view.appearance = NSAppearance(named: .darkAqua)
    view.frame = NSRect(x: 0, y: 0, width: 390, height: model.panelHeight)
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw NSError(domain: "Preview", code: 2)
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Preview", code: 3)
    }
    try png.write(to: URL(fileURLWithPath: output), options: .atomic)
    print(model.title)
}
