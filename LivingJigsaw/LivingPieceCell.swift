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
    var useSynthetic: Bool
    var globalTime: TimeInterval
    var edges: PieceEdges
    var isPlaced: Bool
    var bloomPulse: Bool
    /// Ghép xong — bỏ viền để xem liền mạnh.
    var hideOutlines: Bool = false
    var body: some View {
        ZStack {
            Group {
                if let player, !useSynthetic {
                    VideoPieceRepresentable(player: player, col: col, row: row, cols: cols, rows: rows)
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

            if !hideOutlines {
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
                            : AnyShapeStyle(Color.white.opacity(0.24)),
                        lineWidth: isPlaced ? 2.4 : 1
                    )
                    .shadow(color: isPlaced ? NaturePalette.goldRing.opacity(bloomPulse ? 0.9 : 0.5) : .clear, radius: isPlaced ? 16 : 0)
            }
        }
        .brightness(bloomPulse ? 0.22 : 0)
        .animation(.easeOut(duration: 0.35), value: bloomPulse)
    }
}

private struct VideoPieceRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let col: Int
    let row: Int
    let cols: Int
    let rows: Int

    func makeUIView(context: Context) -> VideoGridPieceUIView {
        VideoGridPieceUIView(player: player, col: col, row: row, cols: cols, rows: rows)
    }

    func updateUIView(_ uiView: VideoGridPieceUIView, context: Context) {
        uiView.replacePlayer(player)
    }
}
