import AppKit
import SwiftUI

/// Build-only CPU rendering works on CI machines without a Metal device.
/// The paths are shared with the panel; no account or preferences are accessed.
@MainActor
func renderAppIcons(directory: String, preview: String?) throws {
    let destination = URL(fileURLWithPath: directory, isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    func writePNG(pixels: Int, to url: URL) throws {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels, height: pixels,
                  bitsPerComponent: 8, bytesPerRow: pixels * 4, space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "AppIcon", code: 1)
        }
        let edge = CGFloat(pixels)
        // Match SwiftUI's downward Y axis and centered tile/mark geometry.
        context.translateBy(x: 0, y: edge)
        context.scaleBy(x: 1, y: -1)
        let bounds = CGRect(x: 0, y: 0, width: edge, height: edge)
        let tile = RoundedRectangle(cornerRadius: edge * 0.18, style: .continuous)
            .path(in: bounds.insetBy(dx: edge * 0.09375, dy: edge * 0.09375))
        context.setFillColor(CGColor(srgbRed: 0.035, green: 0.56, blue: 0.42, alpha: 1))
        context.addPath(tile.cgPath)
        context.fillPath()

        let markEdge = edge * 0.60
        let mark = CGRect(x: (edge - markEdge) / 2, y: (edge - markEdge) / 2 - edge * 0.008,
                          width: markEdge, height: markEdge)
        let ring = ConversationRing().path(in: mark)
        let tint = CGColor(srgbRed: 0.92, green: 1, blue: 0.97, alpha: 1)
        context.setLineWidth(markEdge / 14)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(tint.copy(alpha: 0.24)!)
        context.addPath(ring.cgPath)
        context.strokePath()
        context.setStrokeColor(tint)
        context.addPath(ring.trimmedPath(from: 0, to: 0.76).cgPath)
        context.strokePath()
        context.setFillColor(tint)
        context.addPath(IntelligenceSpark().path(in: mark).cgPath)
        context.fillPath()
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "AppIcon", code: 2)
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard bitmap.pixelsWide == pixels, bitmap.pixelsHigh == pixels,
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppIcon", code: 3)
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
