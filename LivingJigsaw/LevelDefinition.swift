import SwiftUI

enum LevelStage: Int, CaseIterable, Hashable {
    case healingNature = 1
    case zenUrban = 2
    case cosmicBeyond = 3

    var localizationPrefix: String {
        switch self {
        case .healingNature: return "stage1"
        case .zenUrban: return "stage2"
        case .cosmicBeyond: return "stage3"
        }
    }

    var titleKey: String { "\(localizationPrefix)_title" }
    var goalKey: String { "\(localizationPrefix)_goal" }

    static func forLevel(id: Int) -> LevelStage {
        switch id {
        case 1...4: return .healingNature
        case 5...8: return .zenUrban
        default: return .cosmicBeyond
        }
    }
}

struct LevelDefinition: Hashable, Identifiable {
    var id: Int
    var stage: LevelStage
    /// `level_01_title` …
    var titleKey: String
    var subtitleKey: String
    var syntheticPalette: SyntheticPalette
    /// Lưới cắt video theo UV đều: `cols × rows` mảnh = toàn khung hiển thị khi ghép xong.
    var puzzleColumns: Int = 2
    var puzzleRows: Int = 2

    static func level(_ id: Int) -> LevelDefinition {
        all.first { $0.id == id } ?? all[0]
    }

    /// Level 1–4: 2×2; 5–8: 3×3; 9–12: 4×4 (tối đa). Thêm level: bổ sung `LevelVideoCatalog.entries` (stem file trong `Video/`).
    static let all: [LevelDefinition] = [
        LevelDefinition(id: 1, stage: .healingNature, titleKey: "level_01_title", subtitleKey: "level_01_subtitle", syntheticPalette: .stage1a, puzzleColumns: 2, puzzleRows: 2),
        LevelDefinition(id: 2, stage: .healingNature, titleKey: "level_02_title", subtitleKey: "level_02_subtitle", syntheticPalette: .stage1b, puzzleColumns: 2, puzzleRows: 2),
        LevelDefinition(id: 3, stage: .healingNature, titleKey: "level_03_title", subtitleKey: "level_03_subtitle", syntheticPalette: .stage1c, puzzleColumns: 2, puzzleRows: 2),
        LevelDefinition(id: 4, stage: .healingNature, titleKey: "level_04_title", subtitleKey: "level_04_subtitle", syntheticPalette: .stage1d, puzzleColumns: 2, puzzleRows: 2),
        LevelDefinition(id: 5, stage: .zenUrban, titleKey: "level_05_title", subtitleKey: "level_05_subtitle", syntheticPalette: .stage2a, puzzleColumns: 3, puzzleRows: 3),
        LevelDefinition(id: 6, stage: .zenUrban, titleKey: "level_06_title", subtitleKey: "level_06_subtitle", syntheticPalette: .stage2b, puzzleColumns: 3, puzzleRows: 3),
        LevelDefinition(id: 7, stage: .zenUrban, titleKey: "level_07_title", subtitleKey: "level_07_subtitle", syntheticPalette: .stage2c, puzzleColumns: 3, puzzleRows: 3),
        LevelDefinition(id: 8, stage: .zenUrban, titleKey: "level_08_title", subtitleKey: "level_08_subtitle", syntheticPalette: .stage2d, puzzleColumns: 3, puzzleRows: 3),
        LevelDefinition(id: 9, stage: .cosmicBeyond, titleKey: "level_09_title", subtitleKey: "level_09_subtitle", syntheticPalette: .stage3a, puzzleColumns: 4, puzzleRows: 4),
        LevelDefinition(id: 10, stage: .cosmicBeyond, titleKey: "level_10_title", subtitleKey: "level_10_subtitle", syntheticPalette: .stage3b, puzzleColumns: 4, puzzleRows: 4),
        LevelDefinition(id: 11, stage: .cosmicBeyond, titleKey: "level_11_title", subtitleKey: "level_11_subtitle", syntheticPalette: .stage3c, puzzleColumns: 4, puzzleRows: 4),
        LevelDefinition(id: 12, stage: .cosmicBeyond, titleKey: "level_12_title", subtitleKey: "level_12_subtitle", syntheticPalette: .stage3d, puzzleColumns: 4, puzzleRows: 4),
    ]

    /// Lặp 0…3 — vẫn khớp chuỗi localization `stageN_piece_*` có sẵn.
    func pieceAccessibilityKey(index: Int) -> String {
        "\(stage.localizationPrefix)_piece_\(index % 4)"
    }

    static var maxLevelId: Int { all.map(\.id).max() ?? 1 }
    static var minLevelId: Int { all.map(\.id).min() ?? 1 }

    /// 0 (dễ) … 1 (khó nhất) theo thứ tự `id` trong danh sách level.
    var difficultyNormalized: CGFloat {
        let span = CGFloat(Self.maxLevelId - Self.minLevelId)
        guard span > 0 else { return 0 }
        return CGFloat(id - Self.minLevelId) / span
    }

    /// 0 (2×2) … 1 (4×4) — mảnh càng nhiều càng khó.
    private var gridDensityNormalized: CGFloat {
        let n = puzzleColumns * puzzleRows
        return CGFloat(n - 4) / 12.0
    }

    /// Kết hợp độ khó theo thứ tự level + độ dày lưới (tối đa 4×4).
    private var combinedDifficulty: CGFloat {
        min(1, difficultyNormalized * 0.5 + gridDensityNormalized * 0.5)
    }

    /// Bán kính snap (pt).
    var gameplaySnapRadius: CGFloat { max(30, 72 - combinedDifficulty * 34) }
}

private extension SyntheticPalette {
    static let stage1a = SyntheticPalette(deep: Color(red: 0.04, green: 0.12, blue: 0.10), mid: Color(red: 0.10, green: 0.38, blue: 0.28), highlight: Color(red: 0.42, green: 0.78, blue: 0.62), accent: Color(red: 0.25, green: 0.72, blue: 0.55))
    static let stage1b = SyntheticPalette(deep: Color(red: 0.06, green: 0.08, blue: 0.14), mid: Color(red: 0.15, green: 0.22, blue: 0.42), highlight: Color(red: 0.85, green: 0.55, blue: 0.72), accent: Color(red: 0.45, green: 0.75, blue: 0.95))
    static let stage1c = SyntheticPalette(deep: Color(red: 0.12, green: 0.05, blue: 0.05), mid: Color(red: 0.45, green: 0.18, blue: 0.12), highlight: Color(red: 0.92, green: 0.62, blue: 0.22), accent: Color(red: 0.98, green: 0.82, blue: 0.35))
    static let stage1d = SyntheticPalette(deep: Color(red: 0.02, green: 0.06, blue: 0.14), mid: Color(red: 0.08, green: 0.22, blue: 0.42), highlight: Color(red: 0.55, green: 0.75, blue: 0.95), accent: Color(red: 0.75, green: 0.88, blue: 1.0))

    static let stage2a = SyntheticPalette(deep: Color(red: 0.04, green: 0.05, blue: 0.12), mid: Color(red: 0.15, green: 0.12, blue: 0.38), highlight: Color(red: 0.45, green: 0.35, blue: 0.95), accent: Color(red: 0.25, green: 0.85, blue: 0.92))
    static let stage2b = SyntheticPalette(deep: Color(red: 0.1, green: 0.05, blue: 0.02), mid: Color(red: 0.42, green: 0.22, blue: 0.08), highlight: Color(red: 0.98, green: 0.55, blue: 0.22), accent: Color(red: 1.0, green: 0.78, blue: 0.35))
    static let stage2c = SyntheticPalette(deep: Color(red: 0.06, green: 0.04, blue: 0.08), mid: Color(red: 0.22, green: 0.14, blue: 0.28), highlight: Color(red: 0.92, green: 0.45, blue: 0.55), accent: Color(red: 0.55, green: 0.35, blue: 0.98))
    static let stage2d = SyntheticPalette(deep: Color(red: 0.02, green: 0.08, blue: 0.1), mid: Color(red: 0.08, green: 0.35, blue: 0.42), highlight: Color(red: 0.35, green: 0.95, blue: 0.88), accent: Color(red: 0.72, green: 0.35, blue: 0.98))

    static let stage3a = SyntheticPalette(deep: Color(red: 0.06, green: 0.02, blue: 0.12), mid: Color(red: 0.28, green: 0.1, blue: 0.42), highlight: Color(red: 0.72, green: 0.45, blue: 0.95), accent: Color(red: 0.45, green: 0.25, blue: 0.98))
    static let stage3b = SyntheticPalette(deep: Color(red: 0.02, green: 0.02, blue: 0.06), mid: Color(red: 0.35, green: 0.28, blue: 0.08), highlight: Color(red: 0.95, green: 0.78, blue: 0.25), accent: Color(red: 0.55, green: 0.92, blue: 0.95))
    static let stage3c = SyntheticPalette(deep: Color(red: 0.04, green: 0.04, blue: 0.12), mid: Color(red: 0.18, green: 0.12, blue: 0.38), highlight: Color(red: 0.65, green: 0.55, blue: 0.98), accent: Color(red: 0.35, green: 0.92, blue: 0.72))
    static let stage3d = SyntheticPalette(deep: Color(red: 0.03, green: 0.08, blue: 0.06), mid: Color(red: 0.12, green: 0.38, blue: 0.22), highlight: Color(red: 0.55, green: 0.95, blue: 0.65), accent: Color(red: 0.85, green: 0.95, blue: 0.35))
}
