import SwiftUI

/// A conversation outline doubles as a quota ring; the spark suggests AI.
/// This is a fixed brand mark, not a live usage indicator.
struct BrandMark: View {
    private let green = Color(red: 0.05, green: 0.66, blue: 0.47)

    var body: some View {
        ZStack {
            ConversationRing()
                .stroke(green.opacity(0.24), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ConversationRing()
                .trim(from: 0, to: 0.76)
                .stroke(green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            IntelligenceSpark()
                .fill(green)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }
}

private struct ConversationRing: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(scaleX: rect.width / 28, y: rect.height / 28)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        var path = Path()
        path.move(to: CGPoint(x: 14, y: 2.5))
        path.addCurve(to: CGPoint(x: 25.5, y: 13), control1: CGPoint(x: 20.8, y: 2.5), control2: CGPoint(x: 25.5, y: 6.7))
        path.addCurve(to: CGPoint(x: 14, y: 23.5), control1: CGPoint(x: 25.5, y: 19.3), control2: CGPoint(x: 20.8, y: 23.5))
        path.addQuadCurve(to: CGPoint(x: 10.2, y: 22.9), control: CGPoint(x: 12, y: 23.5))
        path.addLine(to: CGPoint(x: 5.2, y: 25.5))
        path.addLine(to: CGPoint(x: 6.1, y: 20.8))
        path.addCurve(to: CGPoint(x: 2.5, y: 13), control1: CGPoint(x: 3.8, y: 18.9), control2: CGPoint(x: 2.5, y: 16.2))
        path.addCurve(to: CGPoint(x: 14, y: 2.5), control1: CGPoint(x: 2.5, y: 6.7), control2: CGPoint(x: 7.2, y: 2.5))
        return path.applying(scale)
    }
}

private struct IntelligenceSpark: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 28, y: rect.minY + rect.height * y / 28)
        }
        var path = Path()
        path.move(to: point(14, 6.8))
        path.addCurve(to: point(20, 13), control1: point(15.2, 11.2), control2: point(15.8, 11.8))
        path.addCurve(to: point(14, 19.2), control1: point(15.8, 14.2), control2: point(15.2, 14.8))
        path.addCurve(to: point(8, 13), control1: point(12.8, 14.8), control2: point(12.2, 14.2))
        path.addCurve(to: point(14, 6.8), control1: point(12.2, 11.8), control2: point(12.8, 11.2))
        path.closeSubpath()
        return path
    }
}
