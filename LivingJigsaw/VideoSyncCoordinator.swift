import AVFoundation
import Combine
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

/// Điều phối video theo **level** (file `Video/LevelNN.*`), fallback bundle, rồi synthetic.
final class VideoSyncCoordinator: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isUsingSyntheticFallback: Bool = true
    @Published private(set) var syncedHostTime: CMTime = .zero
    /// `width / height` sau `preferredTransform` — dùng khớp khung ghép với video; `nil` khi synthetic / chưa đo.
    @Published private(set) var videoDisplayAspectRatio: CGFloat?
    /// `true` khi đã biết synthetic-only **hoặc** đã đo xong aspect từ video — dùng để bootstrap bàn không bị nhảy layout.
    @Published private(set) var puzzleBoardMetricsReady: Bool = false
    /// Dùng cho `AVSampleBufferDisplayLayer` khi phát video (jigsaw hoặc legacy looper).
    @Published private(set) var itemVideoOutput: AVPlayerItemVideoOutput?

    private let jigsaw = VideoJigsawManager()
    private var jigsawTimeCancellable: AnyCancellable?
    private var endObserver: NSObjectProtocol?
    private var legacyLooper: AVPlayerLooper?
    private var legacyCurrentItemObservation: NSKeyValueObservation?

    init() {}

    deinit {
        tearDown()
    }

    private func stopLegacyLooperAndObservation() {
        legacyCurrentItemObservation?.invalidate()
        legacyCurrentItemObservation = nil
        legacyLooper?.disableLooping()
        legacyLooper = nil
    }

    func load(level: LevelDefinition, userPickedLibraryVideoURL: URL? = nil) {
        tearDown()
        isUsingSyntheticFallback = true
        player = nil
        itemVideoOutput = nil
        videoDisplayAspectRatio = nil
        puzzleBoardMetricsReady = false

        if let u = userPickedLibraryVideoURL {
            jigsaw.refreshDiscoveredVideos()
            startJigsawEngine(url: u)
            return
        }

        jigsaw.refreshDiscoveredVideos()
        if let url = jigsaw.resolvedURL(forLevelId: level.id) {
            startJigsawEngine(url: url)
            return
        }
        if let url = Self.bundleURLInVideoFolder(levelId: level.id) {
            startLegacyLoopingPlayer(url: url)
            return
        }
        enterSyntheticOnly()
    }

    private func startJigsawEngine(url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let ok = await self.jigsaw.loadVideo(url: url)
            guard ok else {
                self.startLegacyLoopingPlayer(url: url)
                return
            }
            if let endObserver = self.endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            self.stopLegacyLooperAndObservation()
            self.player = self.jigsaw.queuePlayer
            self.itemVideoOutput = self.jigsaw.itemVideoOutput
            self.isUsingSyntheticFallback = false
            self.bindJigsawTimePublisher()
            self.refreshVideoDisplayAspect(from: self.jigsaw.queuePlayer)
            self.player?.play()
        }
    }

    private func startLegacyLoopingPlayer(url: URL) {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = nil
        jigsaw.tearDown()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        stopLegacyLooperAndObservation()

        let item = AVPlayerItem(url: url)
        Self.applyLightweightDecodeHints(to: item)
        let pixAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        let out = AVPlayerItemVideoOutput(pixelBufferAttributes: pixAttrs)
        let qp = AVQueuePlayer()
        qp.isMuted = true
        let looper = AVPlayerLooper(player: qp, templateItem: item)
        legacyLooper = looper
        legacyCurrentItemObservation = PlayerLooperVideoOutputBinding.observeCurrentItem(player: qp, output: out)
        itemVideoOutput = out
        player = qp
        isUsingSyntheticFallback = false
        refreshVideoDisplayAspect(from: qp)
        qp.play()
        DispatchQueue.main.async { qp.lj_rehomeVideoOutput(out) }
    }

    private func enterSyntheticOnly() {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = nil
        jigsaw.tearDown()
        stopLegacyLooperAndObservation()
        if let p = player {
            PuzzleVideoFrameHub.shared.unregisterPlayer(p)
        }
        player?.pause()
        player = nil
        itemVideoOutput = nil
        isUsingSyntheticFallback = true
        videoDisplayAspectRatio = nil
        puzzleBoardMetricsReady = true
    }

    private func bindJigsawTimePublisher() {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = jigsaw.$currentHostTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] t in
                self?.syncedHostTime = t
            }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    /// Gameplay giữ `muted` để tập trung; khi ghép xong có thể bật tiếng video (session `.playback` để nghe rõ khi ghép xong).
    func setVideoPlaybackMuted(_ muted: Bool) {
        player?.isMuted = muted
        if !muted {
            player?.volume = 1
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
        }
    }

    func tearDown() {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        jigsaw.tearDown()
        stopLegacyLooperAndObservation()
        if let p = player {
            PuzzleVideoFrameHub.shared.unregisterPlayer(p)
        }
        player?.pause()
        player = nil
        itemVideoOutput = nil
        isUsingSyntheticFallback = true
        syncedHostTime = .zero
        videoDisplayAspectRatio = nil
        puzzleBoardMetricsReady = false
    }

    private func refreshVideoDisplayAspect(from player: AVPlayer?) {
        guard let player, let item = player.currentItem else {
            videoDisplayAspectRatio = nil
            puzzleBoardMetricsReady = true
            return
        }
        puzzleBoardMetricsReady = false
        let asset = item.asset
        Task { [weak self] in
            guard let self else { return }
            do {
                let tracks = try await asset.load(.tracks)
                guard let v = tracks.first(where: { $0.mediaType == .video }) else {
                    await MainActor.run {
                        self.videoDisplayAspectRatio = nil
                        self.puzzleBoardMetricsReady = true
                    }
                    return
                }
                let naturalSize = try await v.load(.naturalSize)
                let preferredTransform = try await v.load(.preferredTransform)
                let r = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
                let w = abs(r.width)
                let h = abs(r.height)
                let ar: CGFloat? = (h > 2) ? (w / h) : nil
                await MainActor.run {
                    self.videoDisplayAspectRatio = ar
                    self.puzzleBoardMetricsReady = true
                }
            } catch {
                await MainActor.run {
                    self.videoDisplayAspectRatio = nil
                    self.puzzleBoardMetricsReady = true
                }
            }
        }
    }

    private static func bundleURLInVideoFolder(levelId: Int) -> URL? {
        LevelVideoCatalog.bundleVideoURL(forLevelId: levelId)
    }

    private static func applyLightweightDecodeHints(to item: AVPlayerItem) {
        item.preferredForwardBufferDuration = 1.5
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if #available(iOS 15.0, *) {
            item.preferredMaximumResolution = CGSize(width: 1920, height: 1920)
        }
    }
}
