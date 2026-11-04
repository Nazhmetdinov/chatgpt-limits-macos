import AppKit
import SwiftUI

/// The same vector mark used in the panel, set on a matte macOS icon tile.
/// All dimensions scale together so small and Retina representations agree.
private struct AppIcon: View {
    let edge: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: edge * 0.18, style: .continuous)
                .fill(Color(red: 0.035, green: 0.56, blue: 0.42))
                .frame(width: edge * 0.8125, height: edge * 0.8125)
            BrandMark(tint: Color(red: 0.92, green: 1, blue: 0.97), edge: edge * 0.60)
                .offset(y: -edge * 0.008)
        }
        .frame(width: edge, height: edge)
    }
}

/// Build-only rendering: no account access, notifications or preference writes.
@MainActor
func renderAppIcons(directory: String, preview: String?) throws {
    _ = NSApplication.shared
    let destination = URL(fileURLWithPath: directory, isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    func writePNG(pixels: Int, to url: URL) throws {
        let renderer = ImageRenderer(content: AppIcon(edge: CGFloat(pixels)))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else {
            throw NSError(domain: "AppIcon", code: 1)
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard bitmap.pixelsWide == pixels, bitmap.pixelsHigh == pixels,
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppIcon", code: 2)
        }
        try data.write(to: url, options: .atomic)
    }

    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let suffix = scale == 1 ? "" : "@2x"
            let name = "icon_\(points)x\(points)\(suffix).png"
            try writePNG(pixels: points * scale, to: destination.appendingPathComponent(name))
        }
    }
    if let preview {
        try writePNG(pixels: 512, to: URL(fileURLWithPath: preview))
    }
}
