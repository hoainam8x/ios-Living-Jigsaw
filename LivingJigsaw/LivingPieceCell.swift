import AVFoundation
import SwiftUI
import UIKit

struct LivingPieceCell: View {
    var palette: SyntheticPalette
    var col: Int
    var row: Int
    var cols: Int
    var rows: Int
    var player: AVPlayer?
    /// Khi có: hiển thị qua `AVSampleBufferDisplayLayer` + `AVPlayerItemVideoOutput` (đồng bộ looper).
    var itemVideoOutput: AVPlayerItemVideoOutput? = nil
    var useSynthetic: Bool
    var globalTime: TimeInterval
    var edges: PieceEdges
    var isPlaced: Bool
    var bloomPulse: Bool
    /// 1 = viền jigsaw đầy; 0 = ẩn (fade admire).
    var jigsawStrokeOpacity: CGFloat = 1
    /// Mảnh đang được chọn — viền nội mạnh hơn (kèm overlay ngoài ở `GameplayView`).
    var selectionEmphasized: Bool = false
    var body: some View {
        ZStack {
            Group {
                if let player, !useSynthetic {
                    VideoPieceRepresentable(
                        player: player,
                        itemVideoOutput: itemVideoOutput,
                        col: col,
                        row: row,
                        cols: cols,
                        rows: rows
                    )
                    .id("\(ObjectIdentifier(player))-\(itemVideoOutput != nil)")
                } else {
                    SyntheticLoopView(
                        palette: palette,
                        globalTime: globalTime,
                        col: col,
                        row: row
                    )
                }
            }
            .scaleEffect(useSynthetic ? 1.24 : 1.0, anchor: .center)
            .clipShape(JigsawPieceShape(edges: edges))
            .compositingGroup()

            if jigsawStrokeOpacity > 0.02 {
                JigsawPieceShape(edges: edges)
                    .stroke(
                        isPlaced
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        NaturePalette.champagne,
                                        NaturePalette.goldRing,
                                        Color(red: 0.38, green: 0.92, blue: 0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : (selectionEmphasized && !isPlaced
                                ? AnyShapeStyle(NaturePalette.luxuryStrokeGradient)
                                : AnyShapeStyle(Color.white.opacity(selectionEmphasized && !isPlaced ? 0.42 : 0.24))),
                        lineWidth: isPlaced ? 2.4 : (selectionEmphasized ? 1.85 : 1)
                    )
                    .opacity(Double(jigsawStrokeOpacity))
                    .shadow(
                        color: isPlaced
                            ? NaturePalette.goldRing.opacity(bloomPulse ? 0.9 : 0.5)
                            : (selectionEmphasized ? NaturePalette.goldRing.opacity(0.55) : .clear),
                        radius: isPlaced ? 16 : (selectionEmphasized ? 10 : 0)
                    )
            }
        }
        .allowsHitTesting(false)
        .brightness(bloomPulse ? 0.22 : 0)
        .animation(.easeOut(duration: 0.35), value: bloomPulse)
        .animation(.easeOut(duration: 0.5), value: jigsawStrokeOpacity)
    }
}

private struct VideoPieceRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let itemVideoOutput: AVPlayerItemVideoOutput?
    let col: Int
    let row: Int
    let cols: Int
    let rows: Int

    func makeUIView(context: Context) -> VideoGridPieceUIView {
        VideoGridPieceUIView(player: player, itemVideoOutput: itemVideoOutput, col: col, row: row, cols: cols, rows: rows)
    }

    func updateUIView(_ uiView: VideoGridPieceUIView, context: Context) {
        uiView.replacePlayer(player, itemVideoOutput: itemVideoOutput)
    }
}
