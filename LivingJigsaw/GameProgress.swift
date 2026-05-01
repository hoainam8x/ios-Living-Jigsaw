import Foundation

/// Tiến trình: chỉ mở **level kế** sau khi xong level trước (`maxCompletedLevelId + 1`).
enum GameProgress {
    private static let currentKey = "lj_current_level_id"
    private static let completedKey = "lj_max_completed_level_id"

    private static var capId: Int { LevelDefinition.maxLevelId }

    /// Level đang chọn / “Chơi ngay” — không vượt quá level đã mở khóa.
    static var currentLevelId: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: currentKey)
            let raw: Int
            if v < LevelDefinition.minLevelId || v > capId {
                raw = LevelDefinition.minLevelId
            } else {
                raw = v
            }
            let maxUnlocked = max(maxCompletedLevelId + 1, LevelDefinition.minLevelId)
            return min(raw, min(maxUnlocked, capId))
        }
        set {
            let maxUnlocked = max(maxCompletedLevelId + 1, LevelDefinition.minLevelId)
            let clamped = min(capId, max(LevelDefinition.minLevelId, newValue))
            UserDefaults.standard.set(min(clamped, maxUnlocked), forKey: currentKey)
        }
    }

    /// Level cao nhất đã hoàn thành (0 = chưa có).
    static var maxCompletedLevelId: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: completedKey)
            return min(capId, max(0, v))
        }
        set {
            UserDefaults.standard.set(min(capId, max(0, newValue)), forKey: completedKey)
        }
    }

    static func markCompleted(levelId: Int) {
        maxCompletedLevelId = max(maxCompletedLevelId, levelId)
        if levelId < capId {
            currentLevelId = levelId + 1
        }
    }

    /// Chỉ level `1 … maxCompleted+1` được vào (tuần tự).
    static func isLevelUnlocked(_ levelId: Int) -> Bool {
        guard levelId >= LevelDefinition.minLevelId, levelId <= capId else { return false }
        return levelId <= max(maxCompletedLevelId + 1, LevelDefinition.minLevelId)
    }

    static func isLevelCleared(_ levelId: Int) -> Bool {
        guard levelId >= LevelDefinition.minLevelId, levelId <= capId else { return false }
        return maxCompletedLevelId >= levelId
    }
}
