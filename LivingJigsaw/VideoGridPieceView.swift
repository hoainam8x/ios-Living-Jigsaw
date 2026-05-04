import AVFoundation
import CoreMedia
import CoreVideo
import QuartzCore
import UIKit

// MARK: - CMSampleBuffer từ CVPixelBuffer (đồng bộ AVSampleBufferDisplayLayer)

private enum VideoSampleBufferFactory {
    private static var formatDescByKey: [UInt64: CMVideoFormatDescription] = [:]

    private static func formatDescription(for pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let key = UInt64(w) << 32 | UInt64(h)
        if let c = formatDescByKey[key] { return c }
        var desc: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &desc
        ) == noErr, let d = desc else { return nil }
        formatDescByKey[key] = d
        return d
    }

    static func makeSampleBuffer(
        pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        guard let fmt = formatDescription(for: pixelBuffer) else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        var sample: CMSampleBuffer?
        let st = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: fmt,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        guard st == noErr else { return nil }
        return sample
    }
}

// MARK: - Hub: một CADisplayLink / player — nhiều tile đọc cùng pixel buffer (AVPlayerLooper + decode)

protocol VideoFrameConsumer: AnyObject {
    func ingestVideoFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime)
}

final class PuzzleVideoFrameHub {
    static let shared = PuzzleVideoFrameHub()

    private final class Session {
        weak var player: AVPlayer?
        let output: AVPlayerItemVideoOutput
        var consumers: [WeakConsumer] = []
        init(player: AVPlayer, output: AVPlayerItemVideoOutput) {
            self.player = player
            self.output = output
        }
    }

    private struct WeakConsumer { weak var ref: VideoFrameConsumer? }

    private var sessions: [ObjectIdentifier: Session] = [:]
    private var displayLink: CADisplayLink?
    private let lock = NSLock()

    private init() {}

    func register(player: AVPlayer, output: AVPlayerItemVideoOutput, consumer: VideoFrameConsumer) {
        let id = ObjectIdentifier(player)
        lock.lock()
        defer { lock.unlock() }
        if sessions[id] == nil {
            sessions[id] = Session(player: player, output: output)
        }
        sessions[id]?.consumers.append(WeakConsumer(ref: consumer))
        pruneEmptyConsumers(for: id)
        startLinkIfNeeded()
    }

    func unregister(consumer: VideoFrameConsumer) {
        lock.lock()
        defer { lock.unlock() }
        for id in sessions.keys {
            sessions[id]?.consumers.removeAll { $0.ref === nil || $0.ref === consumer }
        }
        pruneDeadSessions()
        stopLinkIfIdle()
    }

    func unregisterPlayer(_ player: AVPlayer) {
        let id = ObjectIdentifier(player)
        lock.lock()
        defer { lock.unlock() }
        sessions.removeValue(forKey: id)
        stopLinkIfIdle()
    }

    private func pruneEmptyConsumers(for id: ObjectIdentifier) {
        sessions[id]?.consumers.removeAll { $0.ref == nil }
    }

    private func pruneDeadSessions() {
        for id in sessions.keys {
            pruneEmptyConsumers(for: id)
            if sessions[id]?.consumers.isEmpty == true {
                sessions.removeValue(forKey: id)
            }
        }
    }

    private func startLinkIfNeeded() {
        guard displayLink == nil, !sessions.isEmpty else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLinkIfIdle() {
        guard sessions.isEmpty else { return }
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        lock.lock()
        let snapshot = Array(sessions.values)
        lock.unlock()
        let host = CACurrentMediaTime()
        for session in snapshot {
            guard session.player != nil else { continue }
            let itemTime = session.output.itemTime(forHostTime: host)
            guard session.output.hasNewPixelBuffer(forItemTime: itemTime) else { continue }
            var displayPts = CMTime.zero
            guard let pb = session.output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: &displayPts) else { continue }
            for c in session.consumers {
                c.ref?.ingestVideoFrame(pb, presentationTime: displayPts)
            }
        }
    }
}

// MARK: - Grid tile

/// Một ô ghép: crop buffer chung theo (col,row). Ưu tiên `AVSampleBufferDisplayLayer` + `AVPlayerItemVideoOutput` (đồng bộ looper); fallback `AVPlayerLayer`.
final class VideoGridPieceUIView: UIView, VideoFrameConsumer {
    private let col: Int
    private let row: Int
    private let cols: Int
    private let rows: Int
    private weak var avPlayer: AVPlayer?
    private var itemVideoOutput: AVPlayerItemVideoOutput?
    private let contentContainer = UIView()
    private let playerLayer = AVPlayerLayer()
    private let sampleLayer = AVSampleBufferDisplayLayer()
    private var usesSamplePath = false

    init(player: AVPlayer, itemVideoOutput: AVPlayerItemVideoOutput?, col: Int, row: Int, cols: Int, rows: Int) {
        self.col = col
        self.row = row
        self.cols = cols
        self.rows = rows
        self.avPlayer = player
        self.itemVideoOutput = itemVideoOutput
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isOpaque = false
        clipsToBounds = false
        backgroundColor = .clear
        contentContainer.isUserInteractionEnabled = false
        addSubview(contentContainer)

        if let out = itemVideoOutput {
            usesSamplePath = true
            sampleLayer.videoGravity = .resizeAspectFill
            sampleLayer.isOpaque = false
            contentContainer.layer.addSublayer(sampleLayer)
            PuzzleVideoFrameHub.shared.register(player: player, output: out, consumer: self)
        } else {
            usesSamplePath = false
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = UIColor.clear.cgColor
            playerLayer.isOpaque = false
            contentContainer.layer.addSublayer(playerLayer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if usesSamplePath {
            PuzzleVideoFrameHub.shared.unregister(consumer: self)
        }
    }

    override func removeFromSuperview() {
        if usesSamplePath {
            PuzzleVideoFrameHub.shared.unregister(consumer: self)
        }
        super.removeFromSuperview()
    }

    func ingestVideoFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard usesSamplePath else { return }
        if sampleLayer.status == .failed {
            sampleLayer.flush()
        }
        guard let sb = VideoSampleBufferFactory.makeSampleBuffer(pixelBuffer: pixelBuffer, presentationTime: presentationTime) else { return }
        sampleLayer.enqueue(sb)
    }

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

        let layerBounds = contentContainer.bounds
        playerLayer.frame = layerBounds
        sampleLayer.frame = layerBounds
        playerLayer.setAffineTransform(.identity)
        sampleLayer.setAffineTransform(.identity)

        CATransaction.commit()
    }

    func replacePlayer(_ player: AVPlayer, itemVideoOutput: AVPlayerItemVideoOutput?) {
        if usesSamplePath {
            PuzzleVideoFrameHub.shared.unregister(consumer: self)
        }
        avPlayer = player
        self.itemVideoOutput = itemVideoOutput
        if usesSamplePath, let out = itemVideoOutput {
            PuzzleVideoFrameHub.shared.register(player: player, output: out, consumer: self)
        } else {
            playerLayer.player = player
        }
        setNeedsLayout()
    }
}

// MARK: - Full board underlay

final class VideoFullBoardUIView: UIView, VideoFrameConsumer {
    private weak var avPlayer: AVPlayer?
    private var itemVideoOutput: AVPlayerItemVideoOutput?
    private let playerLayer = AVPlayerLayer()
    private let sampleLayer = AVSampleBufferDisplayLayer()
    private var usesSamplePath = false

    init(player: AVPlayer, itemVideoOutput: AVPlayerItemVideoOutput?) {
        self.avPlayer = player
        self.itemVideoOutput = itemVideoOutput
        super.init(frame: .zero)
        clipsToBounds = true
        isOpaque = false
        backgroundColor = .clear
        if let out = itemVideoOutput {
            usesSamplePath = true
            sampleLayer.videoGravity = .resizeAspectFill
            sampleLayer.isOpaque = false
            layer.addSublayer(sampleLayer)
            PuzzleVideoFrameHub.shared.register(player: player, output: out, consumer: self)
        } else {
            usesSamplePath = false
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = UIColor.clear.cgColor
            playerLayer.isOpaque = false
            layer.addSublayer(playerLayer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if usesSamplePath {
            PuzzleVideoFrameHub.shared.unregister(consumer: self)
        }
    }

    override func removeFromSuperview() {
        if usesSamplePath {
            PuzzleVideoFrameHub.shared.unregister(consumer: self)
        }
        super.removeFromSuperview()
    }

    func ingestVideoFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard usesSamplePath else { return }
        if sampleLayer.status == .failed {
            sampleLayer.flush()
        }
        guard let sb = VideoSampleBufferFactory.makeSampleBuffer(pixelBuffer: pixelBuffer, presentationTime: presentationTime) else { return }
        sampleLayer.enqueue(sb)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        sampleLayer.frame = bounds
    }

    func replacePlayer(_ player: AVPlayer, itemVideoOutput: AVPlayerItemVideoOutput?) {
        if usesSamplePath {
            PuzzleVideoFrameHub.shared.unregister(consumer: self)
        }
        avPlayer = player
        self.itemVideoOutput = itemVideoOutput
        if usesSamplePath, let out = itemVideoOutput {
            PuzzleVideoFrameHub.shared.register(player: player, output: out, consumer: self)
        } else {
            playerLayer.player = player
        }
        setNeedsLayout()
    }
}
