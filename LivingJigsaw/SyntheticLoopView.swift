import SwiftUI

/// Fallback “living” surface when no bundled loop exists — drive `globalTime` from one parent `TimelineView`.
struct SyntheticLoopView: View {
    var palette: SyntheticPalette
    var globalTime: TimeInterval
    var col: Int
    var row: Int

    var body: some View {
        Canvas { context, size in
            let t = globalTime + Double(col * 17 + row * 31) * 0.04
            let rect = CGRect(origin: .zero, size: size)
            let deep = palette.deep
            let mid = palette.mid
            let hi = palette.highlight
            let accent = palette.accent

            context.fill(Path(rect), with: .color(deep))

            let baseAngle = t * 0.35 + Double(col - row) * 0.2
            let wave = sin(t * 1.1 + Double(col)) * 0.5 + 0.5
            let stripCount = 5
            for i in 0..<stripCount {
                let u = (Double(i) + wave) / Double(stripCount)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: size.height * CGFloat(u)))
                p.addQuadCurve(
                    to: CGPoint(x: size.width, y: size.height * CGFloat(u + 0.08)),
                    control: CGPoint(x: size.width * 0.5, y: size.height * CGFloat(0.35 + 0.25 * sin(baseAngle + Double(i))))
                )
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
                let opacity = 0.08 + 0.18 * (1.0 - abs(u - 0.5) * 2.0)
                context.fill(p, with: .color(mid.opacity(opacity)))
            }

            let pulse = 0.35 + 0.25 * sin(t * 2.2 + Double(row))
            let orb = CGRect(
                x: size.width * (0.25 + 0.45 * CGFloat(sin(baseAngle) * 0.5 + 0.5)),
                y: size.height * (0.2 + 0.5 * CGFloat(pulse)),
                width: size.width * 0.22,
                height: size.width * 0.22
            )
            context.fill(Path(ellipseIn: orb), with: .color(hi.opacity(0.45)))
            context.stroke(Path(ellipseIn: orb.insetBy(dx: -2, dy: -2)), with: .color(accent.opacity(0.55)), lineWidth: 1.2)
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }
}
