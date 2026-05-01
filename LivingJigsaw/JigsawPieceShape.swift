import SwiftUI

struct JigsawPieceShape: Shape {
    var edges: PieceEdges
    var tabRadius: CGFloat = 0.11

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(w, h) * tabRadius

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        addTop(&path, rect: rect, r: r)
        addRight(&path, rect: rect, r: r)
        addBottom(&path, rect: rect, r: r)
        addLeft(&path, rect: rect, r: r)
        path.closeSubpath()
        return path
    }

    private func addTop(_ path: inout Path, rect: CGRect, r: CGFloat) {
        let midX = rect.midX
        let y0 = rect.minY
        switch edges.top {
        case .flat:
            path.addLine(to: CGPoint(x: rect.maxX, y: y0))
        case .tabOut:
            path.addLine(to: CGPoint(x: midX - r, y: y0))
            path.addArc(
                center: CGPoint(x: midX, y: y0 - r),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: y0))
        case .tabIn:
            path.addLine(to: CGPoint(x: midX - r, y: y0))
            path.addArc(
                center: CGPoint(x: midX, y: y0 + r),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: y0))
        }
    }

    private func addRight(_ path: inout Path, rect: CGRect, r: CGFloat) {
        let midY = rect.midY
        let x1 = rect.maxX
        switch edges.right {
        case .flat:
            path.addLine(to: CGPoint(x: x1, y: rect.maxY))
        case .tabOut:
            path.addLine(to: CGPoint(x: x1, y: midY - r))
            path.addArc(
                center: CGPoint(x: x1 + r, y: midY),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: x1, y: rect.maxY))
        case .tabIn:
            path.addLine(to: CGPoint(x: x1, y: midY - r))
            path.addArc(
                center: CGPoint(x: x1 - r, y: midY),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: x1, y: rect.maxY))
        }
    }

    private func addBottom(_ path: inout Path, rect: CGRect, r: CGFloat) {
        let midX = rect.midX
        let y1 = rect.maxY
        switch edges.bottom {
        case .flat:
            path.addLine(to: CGPoint(x: rect.minX, y: y1))
        case .tabOut:
            path.addLine(to: CGPoint(x: midX + r, y: y1))
            path.addArc(
                center: CGPoint(x: midX, y: y1 + r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: y1))
        case .tabIn:
            path.addLine(to: CGPoint(x: midX + r, y: y1))
            path.addArc(
                center: CGPoint(x: midX, y: y1 - r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.minX, y: y1))
        }
    }

    private func addLeft(_ path: inout Path, rect: CGRect, r: CGFloat) {
        let midY = rect.midY
        let x0 = rect.minX
        switch edges.left {
        case .flat:
            path.addLine(to: CGPoint(x: x0, y: rect.minY))
        case .tabOut:
            path.addLine(to: CGPoint(x: x0, y: midY + r))
            path.addArc(
                center: CGPoint(x: x0 - r, y: midY),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: x0, y: rect.minY))
        case .tabIn:
            path.addLine(to: CGPoint(x: x0, y: midY + r))
            path.addArc(
                center: CGPoint(x: x0 + r, y: midY),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: x0, y: rect.minY))
        }
    }
}
