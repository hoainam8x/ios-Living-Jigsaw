import SwiftUI

enum JigsawEdge: Hashable {
    case flat
    case tabOut
    case tabIn
}

struct PieceEdges: Hashable {
    var top: JigsawEdge
    var right: JigsawEdge
    var bottom: JigsawEdge
    var left: JigsawEdge

    static func profile(col: Int, row: Int, cols: Int, rows: Int) -> PieceEdges {
        let top: JigsawEdge = row == 0 ? .flat : .tabIn
        let bottom: JigsawEdge = row == rows - 1 ? .flat : .tabOut
        let left: JigsawEdge = col == 0 ? .flat : .tabIn
        let right: JigsawEdge = col == cols - 1 ? .flat : .tabOut
        return PieceEdges(top: top, right: right, bottom: bottom, left: left)
    }
}

struct DraggablePiece: Identifiable, Equatable {
    var id: Int
    var correctIndex: Int
    var rotationQuarterTurns: Int
    var isPlaced: Bool
    var dragOffset: CGSize

    /// 0…3 — luôn theo chiều kim đồng hồ, bước 90°.
    var normalizedQuarterTurns: Int {
        let r = rotationQuarterTurns % 4
        return r < 0 ? r + 4 : r
    }

    /// Dùng `rotationQuarterTurns` tuyệt đối (không mod) để mỗi bước +1 luôn thêm −90° cùng chiều, kể cả sau nhiều vòng.
    /// SwiftUI: góc âm = quay theo kim đồng hồ trên màn hình.
    var rotationAngle: Angle {
        .degrees(-Double(rotationQuarterTurns) * 90)
    }
}
