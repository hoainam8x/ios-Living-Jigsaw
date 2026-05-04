import Foundation

/// Đăng ký video bundle theo **level id** → tên file (không extension) trong thư mục `Video/`.
///
/// **Thêm level:** (1) thêm `LevelDefinition` trong `LevelDefinition.swift` (2) thêm một `Entry` tại đây trỏ đúng tên file đã copy vào `Video/`.
enum LevelVideoCatalog {
    struct Entry: Sendable {
        let levelId: Int
        /// Tên file không extension (ví dụ `Level01-ThacNuoc`). Hỗ trợ `.mp4` / `.MP4` / `.mov` …
        let fileStem: String
    }

    /// Nguồn cấu hình duy nhất — khớp file thực tế trong `Video/` ở root project.
    static let entries: [Entry] = [
        Entry(levelId: 1, fileStem: "Level01-ThacNuoc"),
        Entry(levelId: 2, fileStem: "Level02-HoSen"),
        Entry(levelId: 3, fileStem: "Level03-RungPhong"),
        Entry(levelId: 4, fileStem: "Level04-BienDem"),
        Entry(levelId: 5, fileStem: "Level05-MuaCuaBus"),
        Entry(levelId: 6, fileStem: "Level06-PhoDenLong"),
        Entry(levelId: 7, fileStem: "Level07-QuanCafeVang"),
        Entry(levelId: 8, fileStem: "Level08-ThanhPhoTuongLai"),
        Entry(levelId: 9, fileStem: "Level09-TinhVanLoiCuon"),
        Entry(levelId: 10, fileStem: "Level10-HoDenAnhSang"),
        Entry(levelId: 11, fileStem: "Level11-MuaSaoBang"),
        Entry(levelId: 12, fileStem: "Level12-MamSongVuTru"),
    ]

    private static let stemByLevelId: [Int: String] = {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.levelId, $0.fileStem) })
    }()

    /// Stem đã cấu hình, hoặc mặc định `Level%02d` nếu chưa khai báo (ví dụ level mới tạm).
    static func configuredStem(forLevelId levelId: Int) -> String {
        stemByLevelId[levelId] ?? String(format: "Level%02d", levelId)
    }

    /// URL trong bundle `Video/`: ưu catalog → quét thư mục theo `LevelNN` / hậu tố `-` `_`.
    static func bundleVideoURL(forLevelId levelId: Int) -> URL? {
        let stem = configuredStem(forLevelId: levelId)
        if let direct = urlForStemInVideoFolder(stem) { return direct }
        return fuzzyMatchDefaultLevelStem(levelId: levelId)
    }

    // MARK: - Resolve

    private static func urlForStemInVideoFolder(_ resourceStem: String) -> URL? {
        let trimmed = resourceStem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for ext in ["mp4", "m4v", "mov", "MP4", "MOV", "M4V"] {
            if let u = Bundle.main.url(forResource: trimmed, withExtension: ext, subdirectory: "Video") {
                return u
            }
        }
        let keyStem = trimmed.lowercased()
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
            return nameStem == keyStem
        }
    }

    /// `Level01.mp4`, `Level01-foo.mp4`, `LEVEL02_bar.MOV`, …
    private static func fuzzyMatchDefaultLevelStem(levelId: Int) -> URL? {
        let defaultStem = String(format: "Level%02d", levelId)
        for ext in ["mp4", "m4v", "mov", "MP4", "MOV", "M4V"] {
            if let u = Bundle.main.url(forResource: defaultStem, withExtension: ext, subdirectory: "Video") {
                return u
            }
        }
        let key = defaultStem.lowercased()
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
}
