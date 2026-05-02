import AVFoundation
import Combine
import CoreMedia
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

    private var looper: AVPlayerLooper?
    private var timeObserverToken: Any?

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

    /// Khớp `Level01.mp4`, `Level01-Ten.mp4`, `LEVEL02_clip.MOV`, … (không phân biệt hoa thường).
    func resolvedURL(forLevelId levelId: Int) -> URL? {
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

            await MainActor.run {
                let item = AVPlayerItem(asset: asset)
                Self.applyDecodeOptimizations(to: item)
                let qp = AVQueuePlayer()
                qp.isMuted = true
                self.queuePlayer = qp
                self.looper = AVPlayerLooper(player: qp, templateItem: item)
                self.installHostTimeObserver(on: qp)
                qp.play()
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
        if let token = timeObserverToken, let qp = queuePlayer {
            qp.removeTimeObserver(token)
        }
        timeObserverToken = nil
        looper?.disableLooping()
        looper = nil
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
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
            item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
        }
    }
}
