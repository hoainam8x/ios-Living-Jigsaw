import SwiftUI

struct RootView: View {
    enum Phase: Hashable {
        case home
        case levelMenu
        /// `userLibraryVideoURL`: file temp từ ảnh thư viện / video đã chọn.
        case play(level: LevelDefinition, userLibraryVideoURL: URL?)
        case bloom(level: LevelDefinition, advanceProgress: Bool)
    }

    @State private var phase: Phase = .home
    @StateObject private var gameAudio = SpatialAmbientAudio()

    var body: some View {
        Group {
            switch phase {
            case .home:
                HomeView(
                    onPlayCurrent: { phase = .play(level: .level(GameProgress.currentLevelId), userLibraryVideoURL: nil) },
                    onOpenLevelMenu: { phase = .levelMenu },
                    onPlayUserPickedVideo: { url in
                        phase = .play(level: .level(GameProgress.currentLevelId), userLibraryVideoURL: url)
                    }
                )
            case .levelMenu:
                LevelMenuView(
                    onPickLevel: { level in
                        phase = .play(level: level, userLibraryVideoURL: nil)
                    },
                    onClose: { phase = .home }
                )
            case .play(let level, let userLibraryVideoURL):
                NavigationStack {
                    GameplayView(
                        level: level,
                        userPickedLibraryVideoURL: userLibraryVideoURL,
                        onComplete: { phase = .bloom(level: level, advanceProgress: userLibraryVideoURL == nil) },
                        onLeave: { phase = .home }
                    )
                    .environmentObject(gameAudio)
                    .toolbarBackground(NaturePalette.deepForest.opacity(0.92), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .tint(NaturePalette.sunlight)
                }
            case .bloom(let level, let advanceProgress):
                BloomCompletionView(level: level) {
                    if advanceProgress {
                        GameProgress.markCompleted(levelId: level.id)
                    }
                    phase = .home
                }
                .environmentObject(gameAudio)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: phase)
    }
}
