import AVFoundation
import UIKit

/// One puzzle cell: crops the shared `AVPlayer` frame to this `(col,row)` tile of the grid.
final class VideoGridPieceUIView: UIView {
    private let col: Int
    private let row: Int
    private let cols: Int
    private let rows: Int
    private let playerLayer = AVPlayerLayer()
    private let contentContainer = UIView()

    init(player: AVPlayer, col: Int, row: Int, cols: Int, rows: Int) {
        self.col = col
        self.row = row
        self.cols = cols
        self.rows = rows
        super.init(frame: .zero)
        isOpaque = false
        clipsToBounds = false
        backgroundColor = .clear
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.isOpaque = false
        contentContainer.layer.addSublayer(playerLayer)
        addSubview(contentContainer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 2, bounds.height > 2 else { return }

        let cw = bounds.width
        let ch = bounds.height
        let gridW = cw * CGFloat(cols)
        let gridH = ch * CGFloat(rows)
        let ax = (CGFloat(col) + 0.5) * cw
        let ay = (CGFloat(row) + 0.5) * ch
        let anchor = CGPoint(x: ax / gridW, y: ay / gridH)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        contentContainer.transform = .identity
        contentContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        contentContainer.bounds = CGRect(x: 0, y: 0, width: gridW, height: gridH)
        contentContainer.center = CGPoint(
            x: -CGFloat(col) * cw + gridW * 0.5,
            y: -CGFloat(row) * ch + gridH * 0.5
        )

        let oldAp = CGPoint(x: 0.5, y: 0.5)
        contentContainer.layer.anchorPoint = anchor
        contentContainer.center = CGPoint(
            x: contentContainer.center.x + (anchor.x - oldAp.x) * gridW,
            y: contentContainer.center.y + (anchor.y - oldAp.y) * gridH
        )

        playerLayer.frame = contentContainer.bounds
        playerLayer.setAffineTransform(.identity)

        CATransaction.commit()
    }

    func replacePlayer(_ player: AVPlayer) {
        playerLayer.player = player
        setNeedsLayout()
    }
}

/// Video tràn **đúng bounds bàn** — không dùng lưới `cols×rows` của từng ô (tránh nhân kích thước khi frame = cả bàn).
final class VideoFullBoardUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    init(player: AVPlayer) {
        super.init(frame: .zero)
        clipsToBounds = true
        isOpaque = false
        backgroundColor = .clear
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.isOpaque = false
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func replacePlayer(_ player: AVPlayer) {
        playerLayer.player = player
        setNeedsLayout()
    }
}
