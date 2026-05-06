import AVFoundation
import Combine
import CoreMedia
import CoreVideo
import Foundation

/// Quản lý **một** timeline video dùng chung cho mọi mảnh (mask = cửa sổ vào cùng buffer).
/// - Đồng bộ: `AVQueuePlayer` + `AVPlayerLooper` (loop liền mạch) + `addPeriodicTimeObserver` (nhịp 60Hz) xuất `currentHostTime`.
/// - Thư viện động: quét `Bundle/.../Video` và (DEBUG) thư mục từ biến môi trường `LIVING_JIGSAW_VIDEO_DIR`.
final class VideoJigsawManager: ObservableObject {
    @Published private(set) var discoveredVideoURLs: [URL] = []
    /// Một `AVQueuePlayer` — `AVPlayerLayer` có thể gắn chung player này (đồng khung hình).
    @Published private(set) var queuePlayer: AVQueuePlayer?
    /// Timeline chính (dùng cho debug / UI sync; các layer vẫn lấy trực tiếp từ player).
    @Published private(set) var currentHostTime: CMTime = .zero
    /// Xuất pixel buffer đồng bộ looper → `AVSampleBufferDisplayLayer` (không khựng loop).
    private(set) var itemVideoOutput: AVPlayerItemVideoOutput?

    private var looper: AVPlayerLooper?
    private var timeObserverToken: Any?
    private var currentItemObservation: NSKeyValueObservation?

    deinit {
        tearDown()
    }

    /// Quét lại danh sách file video (gọi khi thêm file mới vào bundle `Video/` sau khi build lại, hoặc sau khi đổi thư mục DEBUG).
    func refreshDiscoveredVideos() {
        var collected: [URL] = []
        let fm = FileManager.default

        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["LIVING_JIGSAW_VIDEO_DIR"], !raw.isEmpty {
            let dir = URL(fileURLWithPath: raw, isDirectory: true)
            collected.append(contentsOf: Self.collectVideoFiles(in: dir, fileManager: fm))
        }
        #endif

        if let resourceRoot = Bundle.main.resourceURL {
            let videoDir = resourceRoot.appendingPathComponent("Video", isDirectory: true)
            if fm.fileExists(atPath: videoDir.path) {
                collected.append(contentsOf: Self.collectVideoFiles(in: videoDir, fileManager: fm))
            }
        }

        for ext in ["mp4", "MP4", "m4v", "M4V", "mov", "MOV"] {
            if let found = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Video") {
                collected.append(contentsOf: found)
            }
        }

        var seen = Set<String>()
        let unique = collected.filter { seen.insert($0.standardizedFileURL.path).inserted }
        discoveredVideoURLs = unique.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// Ưu `LevelVideoCatalog`; sau đó danh sách đã quét (DEBUG folder, bundle `Video/`).
    func resolvedURL(forLevelId levelId: Int) -> URL? {
        if let catalog = LevelVideoCatalog.bundleVideoURL(forLevelId: levelId) {
            return catalog
        }
        refreshDiscoveredVideos()
        let key = "level\(String(format: "%02d", levelId))"
        return discoveredVideoURLs.first { url in
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()
            if stem == key { return true }
            if stem.hasPrefix(key + "-") { return true }
            if stem.hasPrefix(key + "_") { return true }
            return false
        }
    }

    /// Tải và phát video; dùng hardware decode mặc định của `AVPlayer` + giới hạn buffer / độ phân giải tối đa để giảm nhiệt.
    func loadVideo(url: URL) async -> Bool {
        await MainActor.run { self.tearDown() }
        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ]
        )
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else { return false }
            _ = try await asset.load(.duration)
            let shouldUseSampleOutput = try await Self.canUseSampleBufferPath(for: asset)

            await MainActor.run {
                let item = AVPlayerItem(asset: asset)
                Self.applyDecodeOptimizations(to: item)
                let out: AVPlayerItemVideoOutput? = {
                    guard shouldUseSampleOutput else { return nil }
                    let pixAttrs: [String: Any] = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                        kCVPixelBufferMetalCompatibilityKey as String: true,
                    ]
                    return AVPlayerItemVideoOutput(pixelBufferAttributes: pixAttrs)
                }()
                self.itemVideoOutput = out
                let qp = AVQueuePlayer()
                qp.isMuted = true
                self.queuePlayer = qp
                self.looper = AVPlayerLooper(player: qp, templateItem: item)
                if let out {
                    self.currentItemObservation = PlayerLooperVideoOutputBinding.observeCurrentItem(player: qp, output: out)
                }
                self.installHostTimeObserver(on: qp)
                qp.play()
                if let out {
                    DispatchQueue.main.async { qp.lj_rehomeVideoOutput(out) }
                }
            }
            return true
        } catch {
            await MainActor.run {
                self.tearDown()
            }
            return false
        }
    }

    func play() {
        queuePlayer?.play()
    }

    func pause() {
        queuePlayer?.pause()
    }

    func tearDown() {
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        if let qp = queuePlayer {
            PuzzleVideoFrameHub.shared.unregisterPlayer(qp)
        }
        if let token = timeObserverToken, let qp = queuePlayer {
            qp.removeTimeObserver(token)
        }
        timeObserverToken = nil
        looper?.disableLooping()
        looper = nil
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        itemVideoOutput = nil
        currentHostTime = .zero
    }

    private func installHostTimeObserver(on player: AVPlayer) {
        let step = CMTime(seconds: 1.0 / 60.0, preferredTimescale: 60_000)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: step, queue: .main) { [weak self] t in
            self?.currentHostTime = t
        }
    }

    private static func collectVideoFiles(in directory: URL, fileManager: FileManager) -> [URL] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        let allowed: Set<String> = ["mp4", "m4v", "mov"]
        return names.compactMap { name -> URL? in
            let ext = (name as NSString).pathExtension.lowercased()
            guard allowed.contains(ext) else { return nil }
            return directory.appendingPathComponent(name)
        }
    }

    private static func applyDecodeOptimizations(to item: AVPlayerItem) {
        item.preferredForwardBufferDuration = 1.5
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if #available(iOS 15.0, *) {
            // Khung decode vuông tối đa — tránh giới hạn 1280×720 làm lệch ưu tiên ngang so với video dọc từ thư viện.
            item.preferredMaximumResolution = CGSize(width: 1920, height: 1920)
        }
    }

    /// `AVPlayerItemVideoOutput` trả raw pixel theo decode orientation; với video có metadata xoay,
    /// dùng `AVPlayerLayer` sẽ giữ chiều hiển thị đúng như preview.
    private static func canUseSampleBufferPath(for asset: AVAsset) async throws -> Bool {
        let tracks = try await asset.load(.tracks)
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else { return false }
        let t = try await videoTrack.load(.preferredTransform)
        let epsilon: CGFloat = 0.0001
        let isIdentity =
            abs(t.a - 1) < epsilon &&
            abs(t.b) < epsilon &&
            abs(t.c) < epsilon &&
            abs(t.d - 1) < epsilon
        return isIdentity
    }
}
