import AVFoundation
import Combine
import CoreMedia
import CoreGraphics
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

    private let jigsaw = VideoJigsawManager()
    private var jigsawTimeCancellable: AnyCancellable?
    private var endObserver: NSObjectProtocol?
    private var legacyPlayer: AVPlayer?

    init() {}

    func load(level: LevelDefinition, userPickedLibraryVideoURL: URL? = nil) {
        tearDown()
        isUsingSyntheticFallback = true
        player = nil
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
            self.legacyPlayer = nil
            if let endObserver = self.endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            self.player = self.jigsaw.queuePlayer
            self.isUsingSyntheticFallback = false
            self.bindJigsawTimePublisher()
            self.refreshVideoDisplayAspect(from: self.jigsaw.queuePlayer)
            self.jigsaw.play()
        }
    }

    private func startLegacyLoopingPlayer(url: URL) {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = nil
        jigsaw.tearDown()
        let item = AVPlayerItem(url: url)
        Self.applyLightweightDecodeHints(to: item)
        let p = AVPlayer(playerItem: item)
        p.actionAtItemEnd = .none
        p.isMuted = true
        legacyPlayer = p
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak p] _ in
            p?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            p?.play()
        }
        player = p
        isUsingSyntheticFallback = false
        refreshVideoDisplayAspect(from: p)
        p.play()
    }

    private func enterSyntheticOnly() {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = nil
        jigsaw.tearDown()
        legacyPlayer?.pause()
        legacyPlayer = nil
        player = nil
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
        jigsaw.queuePlayer?.play() ?? legacyPlayer?.play()
    }

    func pause() {
        jigsaw.pause()
        legacyPlayer?.pause()
    }

    func tearDown() {
        jigsawTimeCancellable?.cancel()
        jigsawTimeCancellable = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        jigsaw.tearDown()
        legacyPlayer?.pause()
        legacyPlayer = nil
        player = nil
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
        let stem = String(format: "Level%02d", levelId)
        for ext in ["mp4", "m4v", "mov", "MP4", "MOV", "M4V"] {
            if let u = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "Video") {
                return u
            }
        }
        let key = stem.lowercased()
        guard let videoDir = Bundle.main.resourceURL?.appendingPathComponent("Video", isDirectory: true),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: videoDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              )
        else { return nil }
        let allowedExt: Set<String> = ["mp4", "m4v", "mov"]
        return urls.first { url in
            let nameStem = url.deletingPathExtension().lastPathComponent.lowercased()
            let ext = url.pathExtension.lowercased()
            guard allowedExt.contains(ext) else { return false }
            return nameStem == key || nameStem.hasPrefix("\(key)-") || nameStem.hasPrefix("\(key)_")
        }
    }

    private static func applyLightweightDecodeHints(to item: AVPlayerItem) {
        item.preferredForwardBufferDuration = 1.5
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if #available(iOS 15.0, *) {
            item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
        }
    }
}
